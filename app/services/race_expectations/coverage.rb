module RaceExpectations
  # Read-only inventory: count prerequisites without fitting/backtesting a model
  # for every race. The same dataset and warm-up rules drive the actual report.
  class Coverage
    def self.call(before:, year: nil)
      races = Race.where("date < ?", before).joins(:race_results).distinct
                  .includes(:qualifying_results, race_results: :status).order(:date, :id).to_a
      events = races.filter_map { |race| Dataset.event(race) }
      entries = races.select { |race| year.nil? || race.year.to_i == year.to_i }.map do |race|
        results = race.race_results.to_a
        size = results.size
        seedable = size >= 2 && results.all? { |result| result.old_elo_v2&.finite? } && results.map(&:driver_id).uniq.size == size
        qualifying = race.qualifying_results.index_by(&:driver_id)
        with_qualifying = results.select { |result| qualifying[result.driver_id]&.position&.between?(1, size) }
        history_ready = Backtest.enough?(Backtest.training_events(events, before: race.date))
        predicted = seedable && history_ready ? with_qualifying : []
        reasons = []
        reasons << "pre_race_elo_or_field" unless seedable
        reasons << "qualifying" if with_qualifying.size < size
        reasons << "earlier_history" unless history_ready
        {
          race_id: race.id, year: race.year, round: race.round, date: race.date,
          entrants: size, estimated: predicted.size,
          assessed: predicted.count { |result| result.classified? && result.position_order&.between?(1, size) },
          missing: reasons
        }
      end
      {
        before: before, year: year, summary: summarize(entries),
        by_year: entries.group_by { |entry| entry[:year] }.transform_values { |group| summarize(group) },
        races: entries
      }
    end

    def self.summarize(entries)
      {
        races_with_results: entries.size,
        full_grid_estimates: entries.count { |entry| entry[:estimated] == entry[:entrants] },
        partial_grid_estimates: entries.count { |entry| entry[:estimated].positive? && entry[:estimated] < entry[:entrants] },
        no_estimates: entries.count { |entry| entry[:estimated].zero? },
        estimated_entrants: entries.sum { |entry| entry[:estimated] },
        assessed_finishers: entries.sum { |entry| entry[:assessed] },
        # Reasons overlap: a race can lack qualifying AND sufficient history.
        missing_prerequisites: entries.flat_map { |entry| entry[:missing] }.tally
      }
    end
  end
end
