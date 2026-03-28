class Prediction < ApplicationRecord
  belongs_to :team1, class_name: "Team"
  belongs_to :team2, class_name: "Team"
  belongs_to :predicted_winner, class_name: "Team", optional: true

  validates :team1_win_probability, :team2_win_probability, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  def team1_pct
    (team1_win_probability * 100).round(1)
  end

  def team2_pct
    (team2_win_probability * 100).round(1)
  end

  def confidence
    [team1_win_probability, team2_win_probability].max
  end

  def play?
    confidence >= PredictionService::PLAY_THRESHOLD
  end

  def xi_team1_list
    xi_team1.present? ? xi_team1.split("\n").map(&:strip).reject(&:empty?) : []
  end

  def xi_team2_list
    xi_team2.present? ? xi_team2.split("\n").map(&:strip).reject(&:empty?) : []
  end
end
