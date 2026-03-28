# Predicts win probabilities using a weighted combination of six factors:
#
#   Factor              Weight  Description
#   ──────────────────────────────────────────────────────────────────────
#   win_rate              0.15  Overall career win rate
#   head_to_head          0.20  H2H record between these two teams
#   recent_form           0.20  Last 10 matches (exponentially weighted)
#   venue_win_rate        0.25  Team's actual record at this specific venue
#   toss_advantage        0.10  Does toss winner tend to win at this venue?
#   season_form           0.10  Current-season form (live, updates each match)
#
# With the full Kaggle dataset (~900 matches), realistic accuracy: 58–63%.
# Getting to 70%+ requires player-level form data (deliveries.csv).
class PredictionService
  WEIGHTS = {
    win_rate:       0.15,
    head_to_head:   0.20,
    recent_form:    0.20,
    venue_win_rate: 0.25,
    toss_advantage: 0.10,
    season_form:    0.10,
  }.freeze

  # before_date: for backtesting — only uses data before this date
  def initialize(team1, team2, venue: nil, toss_winner: nil, before_date: nil)
    @team1       = team1
    @team2       = team2
    @venue       = venue
    @toss_winner = toss_winner
    @before_date = before_date
  end

  def predict
    s1, s2  = weighted_scores
    total   = s1 + s2
    t1_prob = total.zero? ? 0.5 : (s1 / total)
    t2_prob = 1.0 - t1_prob
    winner  = t1_prob >= t2_prob ? @team1 : @team2

    Prediction.new(
      team1:                 @team1,
      team2:                 @team2,
      venue:                 @venue,
      team1_win_probability: t1_prob.round(4),
      team2_win_probability: t2_prob.round(4),
      predicted_winner:      winner
    )
  end

  def predict_and_save
    p = predict
    p.save!
    p
  end

  def breakdown
    factors = raw_factors
    total   = factors[:team1].values.sum + factors[:team2].values.sum
    pct     = ->(v) { total.zero? ? 0 : (v / total * 100).round(1) }
    {
      team1: factors[:team1].transform_values(&pct),
      team2: factors[:team2].transform_values(&pct)
    }
  end

  private

  def weighted_scores
    f  = raw_factors
    w  = WEIGHTS.values.sum
    s1 = WEIGHTS.sum { |k, wt| f[:team1][k] * wt } / w
    s2 = WEIGHTS.sum { |k, wt| f[:team2][k] * wt } / w
    [s1, s2]
  end

  def raw_factors
    @raw_factors ||= {
      team1: compute_factors(@team1),
      team2: compute_factors(@team2),
    }
  end

  def compute_factors(team)
    {
      win_rate:       overall_win_rate(team),
      head_to_head:   h2h_score(team),
      recent_form:    recent_form_score(team),
      venue_win_rate: venue_win_rate(team),
      toss_advantage: toss_advantage_score(team),
      season_form:    season_form_score(team),
    }
  end

  # ─── Factor computations ────────────────────────────────────────────────

  def overall_win_rate(team)
    played = history.where("team1_id = ? OR team2_id = ?", team.id, team.id).count
    return 0.5 if played.zero?
    history.where(winner: team).count.to_f / played
  end

  def h2h_score(team)
    other = opponent(team)
    h2h   = history.where(
      "(team1_id = ? AND team2_id = ?) OR (team1_id = ? AND team2_id = ?)",
      team.id, other.id, other.id, team.id
    )
    return 0.5 if h2h.empty?
    h2h.where(winner: team).count.to_f / h2h.count
  end

  # Exponentially weighted recent form — most recent match has highest weight
  def recent_form_score(team)
    recent = history
               .where("team1_id = ? OR team2_id = ?", team.id, team.id)
               .order(match_date: :desc)
               .limit(10)
    return 0.5 if recent.empty?

    n             = recent.size.to_f
    total_weight  = 0.0
    weighted_wins = 0.0
    recent.each_with_index do |m, i|
      w             = n - i  # most recent = n, oldest = 1
      total_weight  += w
      weighted_wins += w if m.winner_id == team.id
    end
    weighted_wins / total_weight
  end

  # Team's actual win rate at this specific venue
  def venue_win_rate(team)
    return 0.5 if @venue.blank?
    vm = venue_matches.where("team1_id = ? OR team2_id = ?", team.id, team.id)
    return 0.5 if vm.empty?
    vm.where(winner: team).count.to_f / vm.count
  end

  # If toss winner known: use venue toss-to-win rate; otherwise neutral
  def toss_advantage_score(team)
    return 0.5 if @toss_winner.nil?
    rate = toss_to_win_rate
    @toss_winner == team ? rate : (1.0 - rate)
  end

  # Fraction of matches at this venue won by the toss winner
  def toss_to_win_rate
    @toss_to_win_rate ||= begin
      return 0.5 if @venue.blank?
      vm = venue_matches.where.not(toss_winner_id: nil, winner_id: nil)
      return 0.5 if vm.empty?
      vm.where("toss_winner_id = winner_id").count.to_f / vm.count
    end
  end

  # Win rate in the most recent completed season
  def season_form_score(team)
    current = history.maximum(:season)
    return 0.5 unless current
    sm = history.where(season: current)
                .where("team1_id = ? OR team2_id = ?", team.id, team.id)
    return 0.5 if sm.empty?
    sm.where(winner: team).count.to_f / sm.count
  end

  # ─── Helpers ────────────────────────────────────────────────────────────

  def opponent(team)
    team == @team1 ? @team2 : @team1
  end

  def history
    @history ||= begin
      scope = Match.completed
      scope = scope.where("match_date < ?", @before_date) if @before_date
      scope
    end
  end

  def venue_matches
    @venue_matches ||= history.where("venue LIKE ?", "%#{venue_keyword}%")
  end

  # Pick the most distinctive word from the venue name for fuzzy matching
  def venue_keyword
    @venue_keyword ||= begin
      stopwords = %w[cricket stadium ground international]
      words     = @venue.to_s.split(/[\s,]+/).map(&:downcase).reject { |w| w.length < 4 || stopwords.include?(w) }
      words.first || @venue.to_s
    end
  end
end
