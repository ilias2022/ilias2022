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

      # Skip defunct teams or no-result matches
      next if t1_short.nil? || t2_short.nil?
      next if w_short.nil? && row["winner"].present?   # defunct winner
      next if row["result"] == "no result"

      t1     = team_lookup[t1_short]
      t2     = team_lookup[t2_short]
      winner = w_short ? team_lookup[w_short] : nil

      unless t1 && t2
        skipped += 1
        next
      end

      date   = Date.parse(row["date"]) rescue nil
      season = row["season"].to_i

      toss_short  = TEAM_NAME_MAP[row["toss_winner"]&.strip]
      toss_winner = toss_short ? team_lookup[toss_short] : nil

      Match.find_or_create_by!(team1: t1, team2: t2, season: season, match_date: date) do |m|
        m.venue        = row["venue"]&.strip
        m.winner       = winner
        m.toss_winner  = toss_winner
        m.toss_decision = row["toss_decision"]&.strip
      end

      imported += 1
    end

    puts "Done. Imported: #{imported}  Skipped: #{skipped}  Total matches: #{Match.count}"
  end
end
