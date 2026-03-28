class PlayerStat < ApplicationRecord
  validates :player_name, :season, presence: true

  scope :for_seasons, ->(seasons) { where(season: seasons) }

  def strike_rate
    return nil if balls_faced.nil? || balls_faced.zero?
    (total_runs.to_f / balls_faced * 100).round(1)
  end

  def economy
    return nil if balls_bowled.nil? || balls_bowled.zero?
    (runs_conceded.to_f / balls_bowled * 6).round(2)
  end

  def batting_avg
    return nil if matches_batted.nil? || matches_batted.zero?
    (total_runs.to_f / matches_batted).round(1)
  end

  def bowling_avg
    return nil if wickets_taken.nil? || wickets_taken.zero?
    (runs_conceded.to_f / wickets_taken).round(1)
  end

  # Aggregate stats for a list of player names over the last N seasons
  def self.for_players(names, current_season:, lookback: 2)
    seasons = ((current_season - lookback + 1)..current_season).to_a
    where(player_name: names).for_seasons(seasons)
      .group(:player_name)
      .select(
        "player_name",
        "SUM(matches_batted)  AS matches_batted",
        "SUM(total_runs)      AS total_runs",
        "SUM(balls_faced)     AS balls_faced",
        "SUM(matches_bowled)  AS matches_bowled",
        "SUM(wickets_taken)   AS wickets_taken",
        "SUM(runs_conceded)   AS runs_conceded",
        "SUM(balls_bowled)    AS balls_bowled"
      )
  end

  # Team batting strength: avg strike rate of the XI vs league average
  # Returns 0.0–1.0 (0.5 = league average)
  def self.xi_batting_score(player_names, current_season:)
    stats   = for_players(player_names, current_season: current_season)
    batters = stats.select { |s| s.balls_faced.to_i > 20 }
    return 0.5 if batters.empty?

    team_sr  = batters.sum(&:strike_rate) / batters.size
    league_sr = league_strike_rate(current_season)
    return 0.5 if league_sr.zero?

    ratio = team_sr / league_sr
    ((ratio - 0.85) / 0.30).clamp(0.1, 0.9)
  end

  # Team bowling strength: avg economy of the XI vs league average (lower = better)
  def self.xi_bowling_score(player_names, current_season:)
    stats   = for_players(player_names, current_season: current_season)
    bowlers = stats.select { |s| s.balls_bowled.to_i > 30 }
    return 0.5 if bowlers.empty?

    team_eco   = bowlers.sum(&:economy) / bowlers.size
    league_eco = league_economy(current_season)
    return 0.5 if league_eco.zero?

    ratio = team_eco / league_eco
    ((1.15 - ratio) / 0.30).clamp(0.1, 0.9)
  end

  def self.league_strike_rate(current_season)
    seasons = ((current_season - 1)..current_season).to_a
    rows    = for_seasons(seasons).where("balls_faced > 0")
    return 130.0 if rows.empty?  # IPL historical ~130 SR
    total_runs  = rows.sum(:total_runs).to_f
    total_balls = rows.sum(:balls_faced).to_f
    total_balls.zero? ? 130.0 : (total_runs / total_balls * 100)
  end

  def self.league_economy(current_season)
    seasons = ((current_season - 1)..current_season).to_a
    rows    = for_seasons(seasons).where("balls_bowled > 0")
    return 8.5 if rows.empty?  # IPL historical ~8.5 economy
    total_runs  = rows.sum(:runs_conceded).to_f
    total_balls = rows.sum(:balls_bowled).to_f
    total_balls.zero? ? 8.5 : (total_runs / total_balls * 6)
  end
end
