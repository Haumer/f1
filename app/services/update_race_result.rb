require 'json'
require 'open-uri'

class UpdateRaceResult
    ENDPOINT = 'https://ergast.com/api/f1'
    attr_reader :url, :race_results, :driver_standings, :race, :new_drivers

    def initialize(race:)
        @race = race
        @results_data = fetch_results_data
        @standings_data = fetch_standings_data
        @found_new_drivers = false
        @new_drivers = []
    end

    def fetch_results_data
        @url = "#{ENDPOINT}/#{@race.year}/#{@race.round}/results.json"
        JSON.parse(URI.open(url).read)
    end

    def fetch_standings_data
        @url = "#{ENDPOINT}/#{@race.year}/#{@race.round}/driverStandings.json"
        JSON.parse(URI.open(url).read)
    end

    def update_all
        self.results
        self.standings
    end

    def results
        @race_results = @results_data['MRData']['RaceTable']['Races'].first['Results'].map do |race_result|
            driver = Driver.find_by(driver_ref: race_result['Driver']['driverId'])
            if !driver.present?
                @found_new_drivers = true
                constructor = Constructor.find_by(constructor_ref: race_result['Constructor']['constructorId'])
                driver = Driver.create(
                    driver_ref: race_result['Driver']['driverId'],
                    surname: race_result['Driver']['familyName'],
                    forename: race_result['Driver']['givenName'],
                    dob: race_result['Driver']['dateOfBirth'],
                    nationality: race_result['Driver']['nationality'],
                    code: race_result['Driver']['code'],
                    url: race_result['Driver']['url'],
                    number: race_result['number'],
                    first_race_date: race.date,
                    last_race_date: race.date,
                    elo: 1000,
                    color: Driver::CONSTRUCTOR_COLORS[constructor.constructor_ref.to_sym],
                    active: true,
                    skill: nil,
                )
                @new_drivers << driver
                SeasonDriver.create(
                    season: race.season,
                    constructor: constructor,
                    driver: driver,
                    active: true
                )
                DriverCountry.create(
                    driver: driver,
                    country: Country.find_by(nationality: driver.nationality)
                )
            end

             RaceResult.create(
                driver: Driver.find_by(driver_ref: race_result['Driver']['driverId']),
                race: @race,
                constructor: Constructor.find_by(constructor_ref: race_result['Constructor']['constructorId']),
                status: Status.find_by(status_type: race_result['status']),
                position: race_result['position'],
                position_order: race_result['position'],
                points: race_result['points'],
                time: race_result['Time'].present? ? race_result['Time']['time'] : 0,
                laps: race_result['laps'],
                milliseconds: race_result['Time'].present? ? race_result['Time']['millis'] : nil,
                fastest_lap_time: race_result['FastestLap'].present? ? race_result['FastestLap']['Time']['time'] : nil,
                fastest_lap_speed: race_result['FastestLap'].present? ? race_result['FastestLap']['AverageSpeed']['speed'] : nil,
                fastest_lap: race_result['FastestLap'].present? ? race_result['FastestLap']['lap'] : nil,
                grid: race_result['grid'],
                number: race_result['number'],
            )
        end
    end

    def standings
        @driver_standings = @standings_data['MRData']['StandingsTable']['StandingsLists'].first['DriverStandings'].map do |driver_standing|
            driver = Driver.find_by(driver_ref: driver_standing['Driver']['driverId'])

            DriverStanding.create(
                race: @race,
                driver: driver,
                position: driver_standing['position'],
                points: driver_standing['points'],
                wins: driver_standing['wins'],
                points: driver_standing['points'],
            )
            UpdateDriverStanding.new(driver: driver, season: race.season).update
            EloRating::Race.new(race: race).update_driver_ratings
        end
    end
end