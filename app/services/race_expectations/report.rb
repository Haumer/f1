require "digest"

module RaceExpectations
  class Report
    VERSION = "elo-qualifying-v1"
    Assessment = Struct.new(:row, :qualifying, :expected, :low, :high, :reason, :field_size, keyword_init: true) do
      delegate :driver, :result, :seed, :display_position, to: :row

      def difference
        expected - result.position_order if expected && comparable?
      end

      def comparable?
        row.classified? && result.position_order.between?(1, field_size)
      end

      def verdict
        return "Not assessed" unless difference
        return "Range unavailable" unless low && high
        return "Above range" if result.position_order < low
        return "Below range" if result.position_order > high

        "In range"
      end
    end

    attr_reader :race, :profile, :assessments

    def initialize(race:, rows:, qualifying:, history: nil)
      @race = race
      events = history || Dataset.before(race.date)
      # Digest the actual features/outcomes, not only updated_at: Elo replays can
      # use update_all without touching timestamps. Cache only derived numbers.
      key = [VERSION, race.date.iso8601, Digest::SHA256.hexdigest(Marshal.dump(events))]
      @profile = Rails.cache.fetch(key, expires_in: 1.hour) { Backtest.profile(events, before: race.date) }
      @assessments = rows.map { |row| assess(row, qualifying[row.result.driver_id]&.position, rows.size) }
    end

    def predicted_count
      assessments.count { |assessment| assessment.expected }
    end

    private

    def assess(row, qualifying, size)
      qualifying = nil unless qualifying&.between?(1, size)
      assessment = Assessment.new(row: row, qualifying: qualifying, field_size: size)
      assessment.reason = if !row.seed
        "Pre-race Elo unavailable"
      elsif !qualifying
        "Qualifying unavailable"
      elsif !profile[:model]
        "More earlier races needed"
      end
      return assessment if assessment.reason

      sample = { elo: (row.seed - 1).to_f / (size - 1), qualifying: (qualifying - 1).to_f / (size - 1) }
      assessment.expected = 1 + Regression.predict(profile[:model], sample) * (size - 1)
      if (radius = profile[:check][:radius])
        assessment.low = (assessment.expected - radius * (size - 1)).floor.clamp(1, size)
        assessment.high = (assessment.expected + radius * (size - 1)).ceil.clamp(1, size)
      end
      unless assessment.comparable?
        assessment.reason = row.result.classified? ? "Result order unavailable" : "#{row.display_position}: #{row.result.status&.status_type}"
      end
      assessment
    end
  end
end
