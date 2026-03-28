namespace :backtest do
  desc "Backtest prediction model against a season. Usage: rails backtest:run[2025]"
  task :run, [:season] => :environment do |_, args|
    season = (args[:season] || 2025).to_i
    test_matches = Match.completed.for_season(season).includes(:team1, :team2, :winner)

    if test_matches.empty?
      puts "No completed matches found for season #{season}."
      next
    end

    correct = 0
    total   = 0
    results = []

    test_matches.order(:match_date).each do |match|
      # Simulate prediction using only data available BEFORE this match
      t1_wins_before = Match.completed
                            .where("season < ? OR (season = ? AND match_date < ?)", season, season, match.match_date)
                            .where(winner: match.team1).count

      t2_wins_before = Match.completed
                            .where("season < ? OR (season = ? AND match_date < ?)", season, season, match.match_date)
                            .where(winner: match.team2).count

      t1_matches_before = Match.completed
                               .where("season < ? OR (season = ? AND match_date < ?)", season, season, match.match_date)
                               .where("team1_id = ? OR team2_id = ?", match.team1_id, match.team1_id).count

      t2_matches_before = Match.completed
                               .where("season < ? OR (season = ? AND match_date < ?)", season, season, match.match_date)
                               .where("team1_id = ? OR team2_id = ?", match.team2_id, match.team2_id).count

      # Build a lightweight snapshot-based predictor (mirrors PredictionService logic)
      t1_wr = t1_matches_before > 0 ? t1_wins_before.to_f / t1_matches_before : 0.5
      t2_wr = t2_matches_before > 0 ? t2_wins_before.to_f / t2_matches_before : 0.5

      # Head-to-head before this match
      h2h = Match.completed
                 .where("season < ? OR (season = ? AND match_date < ?)", season, season, match.match_date)
                 .where("(team1_id = ? AND team2_id = ?) OR (team1_id = ? AND team2_id = ?)",
                        match.team1_id, match.team2_id, match.team2_id, match.team1_id)
      h2h_total = h2h.count
      t1_h2h = h2h_total > 0 ? h2h.where(winner: match.team1).count.to_f / h2h_total : 0.5
      t2_h2h = h2h_total > 0 ? 1.0 - t1_h2h : 0.5

      # Recent form (last 5 before this match)
      def recent(team_id, before_date, season)
        Match.completed
             .where("season < ? OR (season = ? AND match_date < ?)", season, season, before_date)
             .where("team1_id = ? OR team2_id = ?", team_id, team_id)
             .order(match_date: :desc).limit(5)
      end

      t1_recent = recent(match.team1_id, match.match_date, season)
      t2_recent = recent(match.team2_id, match.match_date, season)
      t1_rf = t1_recent.any? ? t1_recent.where(winner_id: match.team1_id).count.to_f / t1_recent.count : 0.5
      t2_rf = t2_recent.any? ? t2_recent.where(winner_id: match.team2_id).count.to_f / t2_recent.count : 0.5

      # Home advantage
      t1_home = match.venue.present? && match.team1.home_ground.present? &&
                match.venue.downcase.include?(match.team1.home_ground.downcase) ? 1.0 : 0.5
      t2_home = match.venue.present? && match.team2.home_ground.present? &&
                match.venue.downcase.include?(match.team2.home_ground.downcase) ? 1.0 : 0.5

      # Titles
      max_titles = Team.maximum(:titles).to_f
      t1_title = max_titles > 0 ? 0.5 + (match.team1.titles.to_f / max_titles * 0.5) : 0.5
      t2_title = max_titles > 0 ? 0.5 + (match.team2.titles.to_f / max_titles * 0.5) : 0.5

      w = { win_rate: 0.30, h2h: 0.25, recent: 0.25, home: 0.10, titles: 0.10 }
      t1_score = t1_wr * w[:win_rate] + t1_h2h * w[:h2h] + t1_rf * w[:recent] + t1_home * w[:home] + t1_title * w[:titles]
      t2_score = t2_wr * w[:win_rate] + t2_h2h * w[:h2h] + t2_rf * w[:recent] + t2_home * w[:home] + t2_title * w[:titles]

      predicted = t1_score >= t2_score ? match.team1 : match.team2
      actual    = match.winner
      hit       = predicted == actual

      correct += 1 if hit
      total   += 1

      results << {
        date:      match.match_date,
        t1:        match.team1.short_name,
        t2:        match.team2.short_name,
        predicted: predicted.short_name,
        actual:    actual.short_name,
        t1_prob:   (t1_score / (t1_score + t2_score) * 100).round(1),
        hit:       hit
      }
    end

    puts "\nIPL #{season} Backtest Results"
    puts "=" * 60
    puts "%-10s %-5s %-5s %-8s %-8s %-7s %s" % ["Date", "T1", "T2", "Pred", "Actual", "T1%", "Result"]
    puts "-" * 60
    results.each do |r|
      puts "%-10s %-5s %-5s %-8s %-8s %-7s %s" % [
        r[:date], r[:t1], r[:t2], r[:predicted], r[:actual],
        "#{r[:t1_prob]}%", r[:hit] ? "✓" : "✗"
      ]
    end
    puts "=" * 60
    puts "Correct: #{correct}/#{total}  (#{(correct.to_f / total * 100).round(1)}%)"
    puts "Baseline (always pick higher win-rate team): ~55-60% expected"
  end
end
