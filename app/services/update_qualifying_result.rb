require "json"
require "open-uri"

# Writes a race's qualifying classification from Jolpica, falling back to the
# Wikipedia article when Jolpica has nothing yet (it often lags by a day or
# more after the session). Idempotent: rows are keyed on (race, driver) so a
# later, fuller source simply overwrites an earlier, partial one.
#
# Returns the number of qualifying_results now stored for the race (0 when no
# source has published), never nil — a network error counts as "nothing yet".
class UpdateQualifyingResult
  ENDPOINT = "https://api.jolpi.ca/ergast/f1"

  attr_reader :source

  def initialize(race:)
    @race = race
    @source = nil
  end

  def call
    jolpica_rows = fetch_jolpica_rows
    if jolpica_rows.any?
      write_jolpica(jolpica_rows)
      @source = "jolpica"
    elsif @race.url.present?
      wiki_rows = WikipediaQualifyingResultFetcher.new(race: @race).call
      if wiki_rows&.any?
        puts "Jolpica has no qualifying, using Wikipedia for #{@race.year}/#{@race.round} (#{wiki_rows.size} rows)"
        write_wikipedia(wiki_rows)
        @source = "wikipedia"
      end
    end

    @race.qualifying_results.count
  end

  private

  def write_jolpica(rows)
    all_drivers = Driver.all.index_by(&:driver_ref)
    all_constructors = Constructor.all.index_by(&:constructor_ref)

    rows.each do |qr|
      driver = all_drivers[qr["Driver"]["driverId"]]
      next unless driver

      constructor = all_constructors[qr["Constructor"]["constructorId"]]

      QualifyingResult.find_or_initialize_by(race: @race, driver: driver).update!(
        constructor: constructor,
        position: qr["position"],
        q1: qr["Q1"],
        q2: qr["Q2"],
        q3: qr["Q3"]
      )
    end
  end

  def write_wikipedia(rows)
    rows.each do |row|
      QualifyingResult.find_or_initialize_by(race: @race, driver: row[:driver]).update!(
        constructor: row[:constructor],
        position: row[:position],
        q1: row[:q1],
        q2: row[:q2],
        q3: row[:q3]
      )
    end
  end

  def fetch_jolpica_rows
    url = "#{ENDPOINT}/#{@race.year}/#{@race.round}/qualifying.json"
    puts "Fetching qualifying: #{url}"
    data = JSON.parse(URI.open(url, read_timeout: 30).read)
    data.dig("MRData", "RaceTable", "Races")&.first&.dig("QualifyingResults") || []
  rescue OpenURI::HTTPError, Timeout::Error, JSON::ParserError, Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    puts "Error fetching qualifying for #{@race.year}/#{@race.round}: #{e.message}"
    []
  end
end
