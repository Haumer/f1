module Fantasy
  # Turns the browser's JSON payload into the only shape the scoring system
  # accepts. The picker UI already produces this shape; enforcing it on the
  # server keeps a hand-crafted request from repeating an exact pick and being
  # paid more than once for the same driver or position.
  class RacePickPayload
    Result = Struct.new(:picks, :error, keyword_init: true) do
      def success? = error.nil?
    end

    SOURCES = %w[manual random].freeze

    def initialize(raw:, race:)
      @raw = raw
      @race = race
    end

    def call
      parsed = parse
      return failure("Picks could not be read.") unless parsed.is_a?(Array)
      return Result.new(picks: []) if parsed.empty?

      allowed_driver_ids = SeasonDriver.where(season_id: @race.season_id).distinct.pluck(:driver_id)
      return failure("Too many drivers were submitted.") if parsed.size > allowed_driver_ids.size

      picks = parsed.map { |row| normalize_row(row) }
      return failure("Every pick needs a valid driver and position.") if picks.any?(&:nil?)

      driver_ids = picks.map { |pick| pick["driver_id"] }
      positions = picks.map { |pick| pick["position"] }

      return failure("Each driver can only be picked once.") unless driver_ids.uniq.size == driver_ids.size
      return failure("Each position can only be used once.") unless positions.uniq.size == positions.size
      return failure("Picks must start at P1 and stay in order.") unless positions.sort == (1..picks.size).to_a
      return failure("One or more drivers are not on this season's grid.") unless (driver_ids - allowed_driver_ids).empty?

      Result.new(picks: picks.sort_by { |pick| pick["position"] })
    rescue JSON::ParserError, TypeError, ArgumentError
      failure("Picks could not be read.")
    end

    private

    def parse
      @raw.is_a?(String) ? JSON.parse(@raw) : @raw
    end

    def normalize_row(row)
      return unless row.respond_to?(:[])

      driver_id = Integer(row["driver_id"] || row[:driver_id])
      position = Integer(row["position"] || row[:position])
      source = (row["source"] || row[:source] || "manual").to_s
      return unless driver_id.positive? && position.positive? && SOURCES.include?(source)

      { "driver_id" => driver_id, "position" => position, "source" => source }
    rescue TypeError, ArgumentError
      nil
    end

    def failure(message)
      Result.new(picks: [], error: message)
    end
  end
end
