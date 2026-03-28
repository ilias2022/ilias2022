class Match < ApplicationRecord
  belongs_to :team1, class_name: "Team"
  belongs_to :team2, class_name: "Team"
  belongs_to :winner, class_name: "Team", optional: true
  belongs_to :toss_winner, class_name: "Team", optional: true

  validates :team1, :team2, presence: true
  validate :teams_must_differ

  scope :completed, -> { where.not(winner_id: nil) }
  scope :for_season, ->(s) { where(season: s) }

  def teams
    [team1, team2]
  end

  private

  def teams_must_differ
    errors.add(:team2, "must be different from team1") if team1_id == team2_id
  end
end
