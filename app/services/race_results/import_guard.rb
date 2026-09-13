module RaceResults
  # Reject source mixups before resetting results or changing ratings/settlement.
  # A copied table can sit on the correct Wikipedia article, so event identity
  # alone is not sufficient: compare the field with recent classifications too.
  class ImportGuard
    class Rejected < StandardError; end

    def initialize(race:)
      @race = race
    end

    def validate_event!(event)
      matches = event && event['season'].to_s == @race.year.to_s &&
        event['round'].to_s == @race.round.to_s &&
        event['date'].to_s == @race.date.iso8601 &&
        event.dig('Circuit', 'circuitId').to_s == @race.circuit.circuit_ref
      raise Rejected, "Source event does not match race #{@race.id}" unless matches
    end

    # rows contain driver_id, position_order and laps, independent of source.
    def validate_rows!(rows)
      ids = rows.map { |r| r.fetch(:driver_id) }
      raise Rejected, 'Duplicate or unknown drivers in classification' if ids.any?(&:blank?) || ids.uniq.size != ids.size
      return if rows.size < 8

      previous_races.each do |previous|
        earlier = previous.race_results.index_by(&:driver_id)
        matching = rows.count do |row|
          old = earlier[row[:driver_id]]
          old && old.position_order.to_i == row[:position_order].to_i &&
            old.laps.to_i.positive? && old.laps.to_i == row[:laps].to_i
        end
        # Covers small differences from a half-edited placeholder (winner/laps,
        # pit-lane grids) without flagging a merely repeated podium.
        if matching >= 8 && matching.to_f / [rows.size, earlier.size].max >= 0.8
          raise Rejected, "Classification duplicates round #{previous.round} (race #{previous.id})"
        end
      end
      nil
    end

    private

    def previous_races
      Race.where(season_id: @race.season_id).where('date < ?', @race.date)
          .joins(:race_results).distinct.order(date: :desc).limit(3).preload(:race_results)
    end
  end
end
