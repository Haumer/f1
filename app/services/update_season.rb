require 'json'
require 'open-uri'

class UpdateSeason
    ENDPOINT = "https://api.jolpi.ca/ergast/f1/"

    def initialize(year:)
        @year = year
        fetch_season
    end

    def create_season
        return unless @season_data

        races = @season_data.dig("MRData", "RaceTable", "Races")
        return unless races&.any?

        season = Season.find_or_create_by(year: races.first["season"])

        races.each_with_index do |race_data, index|
            last_race = (races.length == index + 1)

            circuit = find_or_create_circuit(race_data["Circuit"])
            next unless circuit

            race = Race.find_or_initialize_by(season: season, round: race_data["round"].to_i)
            race.year = race_data["season"].to_i
            race.date = race_data["date"].to_date
            race.circuit = circuit
            race.url = race_data["url"]
            race.season_end = last_race
            race.time = race_data["time"]
            race.fp1_time = race_data.dig("FirstPractice", "time")
            race.fp2_time = race_data.dig("SecondPractice", "time")
            race.fp3_time = race_data.dig("ThirdPractice", "time")
            race.quali_time = race_data.dig("Qualifying", "time")
            race.save!
        end

        # Update season_end flag on last race (in case schedule changed)
        season.races.update_all(season_end: false)
        season.races.order(round: :desc).limit(1).update_all(season_end: true)

        season
    end

    private

    def fetch_season
        @season_data = JSON.parse(URI.open("#{ENDPOINT}#{@year}.json", read_timeout: 30).read)
    rescue OpenURI::HTTPError, Timeout::Error, JSON::ParserError => e
        puts "Error fetching season #{@year}: #{e.message}"
        @season_data = nil
    end

    def find_or_create_circuit(circuit_data)
        return unless circuit_data

        Circuit.find_or_create_by(circuit_ref: circuit_data["circuitId"]) do |circuit|
            circuit.name = circuit_data["circuitName"]
            location = circuit_data["Location"] || {}
            circuit.location = location["locality"]
            circuit.country = location["country"]
            circuit.lat = location["lat"]&.to_f
            circuit.lng = location["long"]&.to_f
            circuit.url = circuit_data["url"]
        end
    end
end
