class MatchScore < ApplicationRecord
  belongs_to :match
  belongs_to :team

  validates :runs_scored, :wickets_lost, presence: true

  # Rolling batting average for a team over their last N matches before a given date
  def self.batting_avg(team, before_date: nil, limit: 10)
    scope = joins(:match)
              .where(team: team)
              .order("matches.match_date DESC")
              .limit(limit)
    scope = scope.where("matches.match_date < ?", before_date) if before_date
    rows = scope.pluck(:runs_scored)
    rows.empty? ? nil : rows.sum.to_f / rows.size
  end

  # Rolling bowling avg = runs conceded (opponent's runs_scored against this team)
  def self.bowling_avg(team, before_date: nil, limit: 10)
    scope = joins(:match)
              .where.not(team: team)
              .where("match_id IN (?)",
                joins(:match).where(team: team).select("match_scores.match_id"))
              .order("matches.match_date DESC")
              .limit(limit)
    scope = scope.where("matches.match_date < ?", before_date) if before_date
    rows = scope.pluck(:runs_scored)
    rows.empty? ? nil : rows.sum.to_f / rows.size
  end
end
