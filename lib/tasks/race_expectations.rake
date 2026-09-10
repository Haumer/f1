namespace :f1 do
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
