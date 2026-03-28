# Predicts win probabilities using a weighted combination of:
#   1. Overall win rate (historical)
#   2. Head-to-head record between the two teams
#   3. Recent form (last 5 matches)
#   4. Home ground advantage
#   5. IPL titles (proxy for franchise strength)
class PredictionService
  WEIGHTS = {
    win_rate:      0.30,
    head_to_head:  0.25,
    recent_form:   0.25,
    home_advantage: 0.10,
    titles:        0.10
  }.freeze

  def initialize(team1, team2, venue: nil)
    @team1 = team1
    @team2 = team2
    @venue = venue
  end

  def predict
    scores = compute_scores
    total = scores[:team1] + scores[:team2]

    if total.zero?
      team1_prob = 0.5
    else
      team1_prob = scores[:team1] / total
    end

    team2_prob = 1.0 - team1_prob
    winner = team1_prob >= team2_prob ? @team1 : @team2

    Prediction.new(
      team1: @team1,
      team2: @team2,
      venue: @venue,
      team1_win_probability: team1_prob.round(4),
      team2_win_probability: team2_prob.round(4),
      predicted_winner: winner
    )
  end

  def predict_and_save
    prediction = predict
    prediction.save!
    prediction
  end

  def breakdown
    scores = raw_scores
    total_t1 = scores[:team1].values.sum
    total_t2 = scores[:team2].values.sum
    total = total_t1 + total_t2

    {
      team1: scores[:team1].transform_values { |v| total.zero? ? 0 : (v / total * 100).round(1) },
      team2: scores[:team2].transform_values { |v| total.zero? ? 0 : (v / total * 100).round(1) }
    }
  end

  private

  def compute_scores
    scores = raw_scores
    { team1: scores[:team1].values.sum, team2: scores[:team2].values.sum }
  end

  def raw_scores
    {
      team1: {
        win_rate:       win_rate_score(@team1) * WEIGHTS[:win_rate],
        head_to_head:   h2h_score(@team1) * WEIGHTS[:head_to_head],
        recent_form:    @team1.recent_form * WEIGHTS[:recent_form],
        home_advantage: home_advantage_score(@team1) * WEIGHTS[:home_advantage],
        titles:         titles_score(@team1) * WEIGHTS[:titles]
      },
      team2: {
        win_rate:       win_rate_score(@team2) * WEIGHTS[:win_rate],
        head_to_head:   h2h_score(@team2) * WEIGHTS[:head_to_head],
        recent_form:    @team2.recent_form * WEIGHTS[:recent_form],
        home_advantage: home_advantage_score(@team2) * WEIGHTS[:home_advantage],
        titles:         titles_score(@team2) * WEIGHTS[:titles]
      }
    }
  end

  def win_rate_score(team)
    team.total_matches.zero? ? 0.5 : team.win_rate
  end

  def h2h_score(team)
    other = team == @team1 ? @team2 : @team1
    t1_wins = @team1.head_to_head_wins(@team2)
    t2_wins = @team2.head_to_head_wins(@team1)
    total = t1_wins + t2_wins

    return 0.5 if total.zero?
    team == @team1 ? t1_wins.to_f / total : t2_wins.to_f / total
  end

  def home_advantage_score(team)
    return 0.5 if @venue.blank?
    team.home_ground.present? && @venue.downcase.include?(team.home_ground.downcase) ? 1.0 : 0.5
  end

  def titles_score(team)
    max_titles = Team.maximum(:titles).to_f
    return 0.5 if max_titles.zero?
    # Normalize: more titles = stronger franchise, but cap influence
    base = 0.5 + (team.titles.to_f / max_titles) * 0.5
    base
  end
end
