# Predicts win probabilities using a weighted combination of factors.
#
# When playing XIs are provided (pre-match mode), xi_batting and xi_bowling
# features replace the generic match-score batting/bowling strength, giving
# a more accurate, player-level signal.
#
#   Factor              Weight  Description
#   ──────────────────────────────────────────────────────────────────────
#   xi_batting          0.20    XI average strike rate vs league avg  (if XI given)
#   xi_bowling          0.20    XI average economy vs league avg      (if XI given)
#   batting_strength    0.20    Team rolling runs/innings vs league   (fallback)
#   bowling_strength    0.20    Team rolling runs conceded vs league  (fallback)
#   venue_win_rate      0.20    Team's win rate at this specific venue
#   head_to_head        0.15    H2H record between these two teams
#   recent_form         0.10    Last 10 results, exponentially weighted
#   season_form         0.08    Current-season win rate
#   toss_advantage      0.07    Toss-to-win correlation at venue
#
# PLAY signal: predicted probability >= PLAY_THRESHOLD (60%)
class PredictionService
  PLAY_THRESHOLD = 0.60

  WEIGHTS = {
    venue_win_rate:   0.20,
    head_to_head:     0.15,
    batting_strength: 0.175,
    bowling_strength: 0.175,
    recent_form:      0.10,
    season_form:      0.08,
    toss_advantage:   0.07,
    xi_batting:       0.0,   # activated when XI provided (replaces batting_strength)
    xi_bowling:       0.0,   # activated when XI provided (replaces bowling_strength)
  }.freeze

  # xi_team1/xi_team2: array of player name strings from the match team sheet
  # before_date: for backtesting — only uses data before this date
  def initialize(team1, team2, venue: nil, toss_winner: nil,
                 xi_team1: [], xi_team2: [], before_date: nil)
    @team1       = team1
    @team2       = team2
    @venue       = venue
    @toss_winner = toss_winner
    @xi_team1    = Array(xi_team1).map(&:strip).reject(&:empty?)
    @xi_team2    = Array(xi_team2).map(&:strip).reject(&:empty?)
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

  def play?
    p = predict
    [p.team1_win_probability, p.team2_win_probability].max >= PLAY_THRESHOLD
  end

  def breakdown
    factors = raw_factors
    total   = factors[:team1].values.sum + factors[:team2].values.sum
    pct     = ->(v) { total.zero? ? 0 : (v / total * 100).round(1) }
    {
      team1: factors[:team1].reject { |_, v| v.zero? }.transform_values(&pct),
      team2: factors[:team2].reject { |_, v| v.zero? }.transform_values(&pct)
    }
  end

  def xi_provided?
    @xi_team1.any? && @xi_team2.any?
  end

  private

  def effective_weights
    return WEIGHTS unless xi_provided?
    # Swap generic batting/bowling strength for XI-level versions
    WEIGHTS.merge(
      batting_strength: 0.0,
      bowling_strength: 0.0,
      xi_batting:       0.175,
      xi_bowling:       0.175
    )
  end

  def weighted_scores
    f   = raw_factors
    wts = effective_weights
    w   = wts.values.sum
    s1  = wts.sum { |k, wt| f[:team1][k] * wt } / w
    s2  = wts.sum { |k, wt| f[:team2][k] * wt } / w
    [s1, s2]
  end

  def raw_factors
    @raw_factors ||= {
      team1: compute_factors(@team1, @xi_team1),
      team2: compute_factors(@team2, @xi_team2),
    }
  end

  def compute_factors(team, xi)
    current_season = history.maximum(:season) || Date.today.year
    {
      venue_win_rate:   venue_win_rate(team),
      head_to_head:     h2h_score(team),
      batting_strength: batting_strength(team),
      bowling_strength: bowling_strength(team),
      recent_form:      recent_form_score(team),
      season_form:      season_form_score(team),
      toss_advantage:   toss_advantage_score(team),
      xi_batting:       xi.any? ? PlayerStat.xi_batting_score(xi, current_season: current_season) : 0.0,
      xi_bowling:       xi.any? ? PlayerStat.xi_bowling_score(xi, current_season: current_season) : 0.0,
    }
  end

  # ─── Match-score strength features ──────────────────────────────────────

  def batting_strength(team)
    avg = MatchScore.batting_avg(team, before_date: @before_date)
    return 0.5 unless avg
    league = league_batting_avg
    return 0.5 if league.zero?
    ((avg / league - 0.85) / 0.30).clamp(0.1, 0.9)
  end

  def bowling_strength(team)
    avg_conceded = MatchScore.bowling_avg(team, before_date: @before_date)
    return 0.5 unless avg_conceded
    league = league_batting_avg
    return 0.5 if league.zero?
    ((1.15 - avg_conceded / league) / 0.30).clamp(0.1, 0.9)
  end

  def league_batting_avg
    @league_batting_avg ||= begin
      scope = MatchScore.joins(:match)
      scope = scope.where("matches.match_date < ?", @before_date) if @before_date
      scope.average(:runs_scored)&.to_f || 165.0
    end
  end

  # ─── Match-level features ────────────────────────────────────────────────

  def h2h_score(team)
    other = opponent(team)
    h2h   = history.where(
      "(team1_id = ? AND team2_id = ?) OR (team1_id = ? AND team2_id = ?)",
      team.id, other.id, other.id, team.id
    )
    return 0.5 if h2h.empty?
    h2h.where(winner: team).count.to_f / h2h.count
  end

  def recent_form_score(team)
    recent = history
               .where("team1_id = ? OR team2_id = ?", team.id, team.id)
               .order(match_date: :desc).limit(10)
    return 0.5 if recent.empty?
    n, tw, ww = recent.size.to_f, 0.0, 0.0
    recent.each_with_index { |m, i| tw += (n - i); ww += (n - i) if m.winner_id == team.id }
    ww / tw
  end

  def venue_win_rate(team)
    return 0.5 if @venue.blank?
    vm = venue_matches.where("team1_id = ? OR team2_id = ?", team.id, team.id)
    return 0.5 if vm.empty?
    vm.where(winner: team).count.to_f / vm.count
  end

  def toss_advantage_score(team)
    return 0.5 if @toss_winner.nil?
    rate = toss_to_win_rate
    @toss_winner == team ? rate : (1.0 - rate)
  end

  def toss_to_win_rate
    @toss_to_win_rate ||= begin
      return 0.5 if @venue.blank?
      vm = venue_matches.where.not(toss_winner_id: nil, winner_id: nil)
      return 0.5 if vm.empty?
      vm.where("toss_winner_id = winner_id").count.to_f / vm.count
    end
  end

  def season_form_score(team)
    current = history.maximum(:season)
    return 0.5 unless current
    sm = history.where(season: current)
                .where("team1_id = ? OR team2_id = ?", team.id, team.id)
    return 0.5 if sm.empty?
    sm.where(winner: team).count.to_f / sm.count
  end

  # ─── Helpers ────────────────────────────────────────────────────────────

  def opponent(team) = (team == @team1 ? @team2 : @team1)

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

  def venue_keyword
    @venue_keyword ||= begin
      stopwords = %w[cricket stadium ground international]
      words     = @venue.to_s.split(/[\s,]+/).map(&:downcase)
                        .reject { |w| w.length < 4 || stopwords.include?(w) }
      words.first || @venue.to_s
    end
  end
end
