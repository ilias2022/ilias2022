require "csv"
require "open-uri"

namespace :import do
  # Maps every historical team name variant to our short_name
  TEAM_NAME_MAP = {
    "Mumbai Indians"              => "MI",
    "Chennai Super Kings"         => "CSK",
    "Kolkata Knight Riders"       => "KKR",
    "Royal Challengers Bangalore" => "RCB",
    "Royal Challengers Bengaluru" => "RCB",
    "Sunrisers Hyderabad"         => "SRH",
    "Deccan Chargers"             => "SRH",   # predecessor franchise
    "Rajasthan Royals"            => "RR",
    "Delhi Capitals"              => "DC",
    "Delhi Daredevils"            => "DC",    # renamed 2019
    "Punjab Kings"                => "PBKS",
    "Kings XI Punjab"             => "PBKS",  # renamed 2021
    "Gujarat Titans"              => "GT",
    "Lucknow Super Giants"        => "LSG",
    # Defunct – skip these rows
    "Rising Pune Supergiant"      => nil,
    "Rising Pune Supergiants"     => nil,
    "Gujarat Lions"               => nil,
    "Kochi Tuskers Kerala"        => nil,
    "Pune Warriors India"         => nil,
    "Pune Warriors"               => nil,
  }.freeze

  desc "Import IPL matches from Kaggle CSV. Usage: rails import:matches[path/to/matches.csv]"
  task :matches, [:source] => :environment do |_, args|
    source = args[:source] ||
      "https://raw.githubusercontent.com/avinashyadav16/ipl-analytics/main/matches_2008-2024.csv"

    puts "Loading from: #{source}"
    raw = source.start_with?("http") ? URI.open(source).read : File.read(source)

    team_lookup = Team.all.index_by(&:short_name)
    imported = skipped = 0

    CSV.parse(raw, headers: true) do |row|
      t1_short = TEAM_NAME_MAP[row["team1"]&.strip]
      t2_short = TEAM_NAME_MAP[row["team2"]&.strip]
      w_short  = TEAM_NAME_MAP[row["winner"]&.strip]

      next if t1_short.nil? || t2_short.nil?
      next if w_short.nil? && row["winner"].present?
      next if row["result"] == "no result"

      t1     = team_lookup[t1_short]
      t2     = team_lookup[t2_short]
      winner = w_short ? team_lookup[w_short] : nil

      unless t1 && t2
        skipped += 1
        next
      end

      date         = Date.parse(row["date"]) rescue nil
      season       = row["season"].to_i
      kaggle_id    = row["id"].to_i
      toss_short   = TEAM_NAME_MAP[row["toss_winner"]&.strip]
      toss_winner  = toss_short ? team_lookup[toss_short] : nil

      match = Match.find_or_create_by!(team1: t1, team2: t2, season: season, match_date: date) do |m|
        m.venue           = row["venue"]&.strip
        m.winner          = winner
        m.toss_winner     = toss_winner
        m.toss_decision   = row["toss_decision"]&.strip
        m.kaggle_match_id = kaggle_id
      end

      # Back-fill kaggle_match_id on already-existing rows
      if match.kaggle_match_id.nil? && kaggle_id > 0
        match.update_columns(kaggle_match_id: kaggle_id)
      end

      imported += 1
    end

    puts "Done. Imported: #{imported}  Skipped: #{skipped}  Total matches: #{Match.count}"
  end

  desc "Import deliveries CSV and aggregate into match_scores. Usage: rails import:deliveries[path/or/url]"
  task :deliveries, [:source] => :environment do |_, args|
    source = args[:source] ||
      "https://raw.githubusercontent.com/avinashyadav16/ipl-analytics/main/deliveries_2008-2024.csv"

    puts "Loading deliveries from: #{source}"
    raw = source.start_with?("http") ? URI.open(source).read : File.read(source)

    team_lookup     = Team.all.index_by(&:short_name)
    match_by_kaggle = Match.where.not(kaggle_match_id: nil).index_by(&:kaggle_match_id)

    # Aggregate: { kaggle_match_id => { "Team Name" => { runs: N, wickets: N } } }
    aggregated = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = { runs: 0, wickets: 0 } } }

    CSV.parse(raw, headers: true, header_converters: ->(h) { h&.strip }) do |row|
      mid          = row["match_id"].to_i
      batting_team = row["batting_team"]&.strip
      total_runs   = row["total_runs"].to_i
      is_wicket    = row["is_wicket"].to_i

      aggregated[mid][batting_team][:runs]    += total_runs
      aggregated[mid][batting_team][:wickets] += is_wicket
    end

    puts "Aggregated #{aggregated.size} matches from deliveries. Saving match scores..."

    created = skipped = 0

    aggregated.each do |kaggle_id, teams|
      match = match_by_kaggle[kaggle_id]
      next if match.nil?

      teams.each do |team_name, stats|
        short = TEAM_NAME_MAP[team_name]
        next if short.nil?
        team = team_lookup[short]
        next if team.nil?

        MatchScore.find_or_create_by!(match: match, team: team) do |ms|
          ms.runs_scored  = stats[:runs]
          ms.wickets_lost = stats[:wickets]
        end
        created += 1
      end

      skipped += 1 if teams.empty?
    end

    puts "Done. MatchScores created: #{created}  Matches skipped: #{skipped}  Total: #{MatchScore.count}"
  end

  desc "Aggregate player batting/bowling stats from deliveries CSV. Usage: rails import:player_stats[url]"
  task :player_stats, [:source] => :environment do |_, args|
    source = args[:source] ||
      "https://raw.githubusercontent.com/avinashyadav16/ipl-analytics/main/deliveries_2008-2024.csv"

    puts "Loading deliveries for player stats from: #{source}"
    raw = source.start_with?("http") ? URI.open(source).read : File.read(source)

    # Build match_id → season lookup
    season_by_kaggle = Match.where.not(kaggle_match_id: nil).pluck(:kaggle_match_id, :season).to_h

    # Aggregate: { [player, season] => { batting: {...}, bowling: {...} } }
    batting = Hash.new { |h, k| h[k] = { matches: Set.new, runs: 0, balls: 0 } }
    bowling = Hash.new { |h, k| h[k] = { matches: Set.new, wickets: 0, runs: 0, balls: 0 } }

    CSV.parse(raw, headers: true, header_converters: ->(h) { h&.strip }) do |row|
      mid    = row["match_id"].to_i
      season = season_by_kaggle[mid]
      next unless season

      batter    = row["batter"]&.strip
      bowler    = row["bowler"]&.strip
      b_runs    = row["batsman_runs"].to_i
      t_runs    = row["total_runs"].to_i
      is_wicket = row["is_wicket"].to_i
      # Wide balls don't count as a ball faced by batter but do count for bowler
      extras_type = row["extras_type"]&.strip
      is_wide     = extras_type == "wides"

      if batter.present?
        key = [batter, season]
        batting[key][:matches] << mid
        batting[key][:runs]  += b_runs
        batting[key][:balls] += 1 unless is_wide
      end

      if bowler.present?
        key = [bowler, season]
        bowling[key][:matches] << mid
        bowling[key][:wickets] += is_wicket
        bowling[key][:runs]    += t_runs
        bowling[key][:balls]   += 1 unless is_wide
      end
    end

    puts "Saving player stats (#{batting.size} batting entries, #{bowling.size} bowling entries)..."

    all_keys = (batting.keys + bowling.keys).uniq
    upserted = 0

    all_keys.each do |player, season|
      bat = batting[[player, season]]
      bwl = bowling[[player, season]]

      PlayerStat.find_or_initialize_by(player_name: player, season: season).tap do |ps|
        ps.matches_batted  = bat ? bat[:matches].size : 0
        ps.total_runs      = bat ? bat[:runs]         : 0
        ps.balls_faced     = bat ? bat[:balls]        : 0
        ps.matches_bowled  = bwl ? bwl[:matches].size : 0
        ps.wickets_taken   = bwl ? bwl[:wickets]      : 0
        ps.runs_conceded   = bwl ? bwl[:runs]         : 0
        ps.balls_bowled    = bwl ? bwl[:balls]        : 0
        ps.save!
      end

      upserted += 1
    end

    puts "Done. PlayerStats upserted: #{upserted}  Total: #{PlayerStat.count}"
  end

  desc "Run all imports in order: matches → deliveries → player_stats"
  task :all => [:matches, :deliveries, :player_stats] do
    puts "All imports complete."
  end
end
