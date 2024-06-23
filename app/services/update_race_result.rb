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
        puts "fetching results"
        @url = "#{ENDPOINT}/#{@race.year}/#{@race.round}/results.json"
        JSON.parse(URI.open(url).read)
    end

    def fetch_standings_data
        puts "fetching standings"
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
            constructor = Constructor.find_or_create_by(constructor_ref: race_result['Constructor']['constructorId'], name: race_result['Constructor']['name'], url: race_result['Constructor']['url'])
            if !driver.present?
                @found_new_drivers = true
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
            end

            SeasonDriver.find_or_create_by(
                season: race.season,
                constructor: constructor,
                driver: driver,
                active: true
            )
            DriverCountry.find_or_create_by(
                driver: driver,
                country: Country.find_by(nationality: driver.nationality)
            )

            
            new_race_result = RaceResult.find_or_create_by(
                driver: driver,
                race: @race,
                constructor: constructor,
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

            DriverStanding.find_or_create_by(
                race: @race,
                driver: driver,
                position: driver_standing['position'],
                points: driver_standing['points'],
                wins: driver_standing['wins'],
                points: driver_standing['points'],
            )
            driver.update(last_race_date: @race.date)
            UpdateDriverStanding.new(driver: driver, season: race.season).update
            EloRating::Race.new(race: race).update_driver_ratings
        end
    end
end