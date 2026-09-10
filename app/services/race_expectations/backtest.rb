module RaceExpectations
  class Backtest
    WINDOW_YEARS = 10
    MIN_RACES = 20
    MIN_FINISHES = 200
    MIN_CHECK_RACES = 5
    MIN_CHECK_FINISHES = 100

    def self.training_events(events, before:)
      events.select { |event| event[:date] < before && event[:date] >= before - WINDOW_YEARS.years }
    end

    def self.enough?(events)
      events.size >= MIN_RACES && events.sum { |event| event[:samples].size } >= MIN_FINISHES
    end

    # Hold out entire races, not random driver rows. Fit each forecast using only
    # older races, then record errors. No target-race outcome enters its model.
    def self.evaluate(events, from: nil)
      errors = { combined: [], elo: [], qualifying: [] }
      normalised_errors = []
      tested_races = 0
      events.sort_by { |event| [event[:date], event[:id]] }.each do |event|
        next if from && event[:date] < from

        training = training_events(events, before: event[:date])
        next unless enough?(training)

        samples = training.flat_map { |earlier| earlier[:samples] }
        models = { combined: Regression.fit(samples), elo: Regression.fit(samples, features: [:elo]),
                   qualifying: Regression.fit(samples, features: [:qualifying]) }
        tested_races += 1
        event[:samples].each do |sample|
          models.each do |name, model|
            error = (Regression.predict(model, sample) - sample[:finish]).abs
            errors[name] << error * (sample[:field_size] - 1)
            normalised_errors << error if name == :combined
          end
        end
      end
      enough_checks = tested_races >= MIN_CHECK_RACES && normalised_errors.size >= MIN_CHECK_FINISHES
      # Empirical absolute-error envelope, not a claimed conditional confidence
      # interval. It covers 80% of earlier held-out errors in this sample.
      radius = normalised_errors.sort[(normalised_errors.size * 0.8).ceil - 1] if enough_checks
      { races: tested_races, finishes: normalised_errors.size, radius: radius,
        mae: errors.transform_values { |values| values.sum / values.size if values.any? } }
    end

    def self.profile(events, before:)
      # Defence in depth for injected/cached datasets as well as the SQL filter.
      earlier = events.select { |event| event[:date] < before }
      training = training_events(earlier, before: before)
      {
        model: enough?(training) ? Regression.fit(training.flat_map { |event| event[:samples] }) : nil,
        races: training.size, finishes: training.sum { |event| event[:samples].size },
        first_date: training.map { |event| event[:date] }.min,
        last_date: training.map { |event| event[:date] }.max,
        check: evaluate(earlier, from: before - WINDOW_YEARS.years)
      }
    end
  end
end
