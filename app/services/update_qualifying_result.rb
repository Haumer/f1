require "json"
require "open-uri"

class UpdateQualifyingResult
  ENDPOINT = "https://api.jolpi.ca/ergast/f1"

  def initialize(race:)
    @race = race
  end

  def call
    data = fetch_data
    return unless data

    races = data.dig("MRData", "RaceTable", "Races")
    return unless races&.first

    quali_results = races.first["QualifyingResults"]
    return unless quali_results&.any?

    all_drivers = Driver.all.index_by(&:driver_ref)
    all_constructors = Constructor.all.index_by(&:constructor_ref)

    quali_results.each do |qr|
      driver = all_drivers[qr["Driver"]["driverId"]]
      next unless driver

      constructor = all_constructors[qr["Constructor"]["constructorId"]]

      QualifyingResult.find_or_initialize_by(
        race: @race,
        driver: driver
      ).update!(
        constructor: constructor,
        position: qr["position"],
        q1: qr["Q1"],
        q2: qr["Q2"],
        q3: qr["Q3"]
      )
    end

    @race.qualifying_results.count
  end

  private

  def fetch_data
    url = "#{ENDPOINT}/#{@race.year}/#{@race.round}/qualifying.json"
    puts "Fetching qualifying: #{url}"
    JSON.parse(URI.open(url, read_timeout: 30).read)
  rescue OpenURI::HTTPError, Timeout::Error, JSON::ParserError, Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    puts "Error fetching qualifying for #{@race.year}/#{@race.round}: #{e.message}"
    nil
  end
end
