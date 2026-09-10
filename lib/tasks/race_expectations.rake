namespace :f1 do
  desc "Read-only expectation coverage audit (optional YEAR=2026 AS_OF=YYYY-MM-DD DETAILS=1)"
  task expectations_coverage: :environment do
    date = Date.iso8601(ENV.fetch("AS_OF", Date.current.iso8601))
    report = RaceExpectations::Coverage.call(before: date + 1.day, year: ENV["YEAR"]&.to_i)
    report.delete(:races) unless ENV["DETAILS"] == "1"
    puts JSON.pretty_generate(report)
  end

  desc "Read-only rolling backtest of Elo + qualifying finish estimates (AS_OF=YYYY-MM-DD)"
  task expectations_backtest: :environment do
    date = Date.iso8601(ENV.fetch("AS_OF", Date.current.iso8601))
    events = RaceExpectations::Dataset.before(date)
    puts JSON.pretty_generate(
      version: RaceExpectations::Report::VERSION, as_of: date, available_races: events.size,
      target: "Classified finish position, normalised to the stored race field",
      training_window_years: RaceExpectations::Backtest::WINDOW_YEARS,
      all_history_rolling_check: RaceExpectations::Backtest.evaluate(events),
      current_profile: RaceExpectations::Backtest.profile(events, before: date)
    )
  end
end
