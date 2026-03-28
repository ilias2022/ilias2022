namespace :backtest do
  desc "Backtest prediction model against a season. Usage: rails backtest:run[2025]"
  task :run, [:season] => :environment do |_, args|
    season = (args[:season] || 2025).to_i
    test_matches = Match.completed.for_season(season).order(:match_date).includes(:team1, :team2, :winner, :toss_winner)

    if test_matches.empty?
      puts "No completed matches found for season #{season}."
      next
    end

    correct = 0
    total   = 0
    conf_buckets = Hash.new { |h, k| h[k] = { correct: 0, total: 0 } }

    puts "\nIPL #{season} Backtest Results"
    puts "=" * 70
    puts "%-10s %-5s %-5s %-8s %-8s %-7s %s" % ["Date", "T1", "T2", "Pred", "Actual", "Conf%", ""]
    puts "-" * 70

    test_matches.each do |match|
      service = PredictionService.new(
        match.team1,
        match.team2,
        venue:       match.venue,
        toss_winner: match.toss_winner,
        before_date: match.match_date
      )
      prediction = service.predict

      predicted = prediction.predicted_winner
      actual    = match.winner
      hit       = predicted == actual
      conf      = [prediction.team1_win_probability, prediction.team2_win_probability].max

      correct += 1 if hit
      total   += 1

      bucket = ((conf * 100).floor / 10) * 10
      conf_buckets[bucket][:total]   += 1
      conf_buckets[bucket][:correct] += 1 if hit

      puts "%-10s %-5s %-5s %-8s %-8s %-7s %s" % [
        match.match_date, match.team1.short_name, match.team2.short_name,
        predicted.short_name, actual.short_name,
        "#{(conf * 100).round(1)}%",
        hit ? "✓" : "✗"
      ]
    end

    puts "=" * 70
    puts "Correct: #{correct}/#{total}  (#{(correct.to_f / total * 100).round(1)}%)"
    puts "\nConfidence breakdown:"
    puts "  %-12s %-8s %-8s %s" % ["Confidence", "Correct", "Total", "Accuracy"]
    conf_buckets.sort.each do |bucket, data|
      acc = data[:total] > 0 ? (data[:correct].to_f / data[:total] * 100).round(1) : 0
      puts "  %-12s %-8s %-8s %s" % ["#{bucket}-#{bucket + 9}%%", data[:correct], data[:total], "#{acc}%"]
    end
  end

  desc "Show model accuracy across all seasons"
  task :all_seasons => :environment do
    seasons = Match.completed.distinct.pluck(:season).sort
    puts "\n%-8s %-10s %s" % ["Season", "Correct", "Accuracy"]
    puts "-" * 30
    seasons.each do |s|
      Rake::Task["backtest:run"].reenable
      # Capture output for summary line only
      correct = total = 0
      Match.completed.for_season(s).order(:match_date).includes(:team1, :team2, :winner, :toss_winner).each do |match|
        svc  = PredictionService.new(match.team1, match.team2, venue: match.venue, toss_winner: match.toss_winner, before_date: match.match_date)
        pred = svc.predict
        correct += 1 if pred.predicted_winner == match.winner
        total   += 1
      end
      puts "%-8s %-10s #{total > 0 ? (correct.to_f / total * 100).round(1) : 0}%" % [s, "#{correct}/#{total}"]
    end
  end
end
