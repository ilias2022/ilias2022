class Team < ApplicationRecord
  has_many :home_matches, class_name: "Match", foreign_key: :team1_id
  has_many :away_matches, class_name: "Match", foreign_key: :team2_id
  has_many :wins, class_name: "Match", foreign_key: :winner_id

  validates :name, presence: true, uniqueness: true
  validates :short_name, presence: true, uniqueness: true

  def matches
    Match.where("team1_id = ? OR team2_id = ?", id, id)
  end

  def total_matches
    matches.count
  end

  def win_rate
    return 0.0 if total_matches.zero?
    wins.count.to_f / total_matches
  end

  def head_to_head_wins(other_team)
    wins.where(
      "(team1_id = ? AND team2_id = ?) OR (team1_id = ? AND team2_id = ?)",
      id, other_team.id, other_team.id, id
    ).count
  end

  def recent_form(n = 5)
    recent = matches.order(match_date: :desc).limit(n)
    return 0.0 if recent.empty?
    recent.where(winner_id: id).count.to_f / recent.count
  end
end
