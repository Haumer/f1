require 'json'
require 'open-uri'

class UpdateRaceResult
    ENDPOINT = 'https://api.jolpi.ca/ergast/f1'
    attr_reader :url, :race_results, :driver_standings, :race, :new_drivers

    def initialize(race:)
        @race = race
        @results_data = fetch_results_data
        @standings_data = has_jolpica_results? ? fetch_standings_data : nil
        @new_drivers = []
    end

    def fetch_results_data
        puts "fetching results"
        @url = "#{ENDPOINT}/#{@race.year}/#{@race.round}/results.json"
        JSON.parse(URI.open(url, read_timeout: 30).read)
    rescue OpenURI::HTTPError, Timeout::Error, JSON::ParserError => e
        puts "Error fetching results for #{@race.year}/#{@race.round}: #{e.message}"
        nil
    end

    def fetch_standings_data
        puts "fetching standings"
        @url = "#{ENDPOINT}/#{@race.year}/#{@race.round}/driverStandings.json"
        JSON.parse(URI.open(url, read_timeout: 30).read)
    rescue OpenURI::HTTPError, Timeout::Error, JSON::ParserError => e
        puts "Error fetching standings for #{@race.year}/#{@race.round}: #{e.message}"
        nil
    end

    def update_all
        if has_jolpica_results?
            puts "Using Jolpica API for #{@race.year}/#{@race.round}"
            self.results
            self.standings
        elsif @race.url.present?
            puts "Jolpica has no results, trying Wikipedia for #{@race.year}/#{@race.round}..."
            wiki_results = WikipediaRaceResultFetcher.new(race: @race).call
            if wiki_results&.any?
                puts "Found #{wiki_results.size} results from Wikipedia"
                create_results_from_wikipedia(wiki_results)
                create_standings_from_results
            else
                puts "No results available from any source for #{@race.year}/#{@race.round}"
                return
            end
        else
            return
        end

        EloRatingV2.process_race(@race)
        ConstructorEloV2.process_race(@race)
    end

    def results
        races = @results_data.dig('MRData', 'RaceTable', 'Races')
        return unless races&.first

        all_drivers = Driver.all.index_by(&:driver_ref)
        all_countries = Country.all.index_by(&:nationality)
        all_statuses = Status.all.index_by(&:status_type)

        @race_results = races.first['Results'].map do |race_result|
            driver = all_drivers[race_result['Driver']['driverId']]
            constructor = Constructor.find_or_create_by(constructor_ref: race_result['Constructor']['constructorId']) do |c|
                c.name = race_result['Constructor']['name']
                c.url = race_result['Constructor']['url']
            end
            unless driver
                driver = Driver.create(
                    driver_ref: race_result['Driver']['driverId'],
                    surname: race_result['Driver']['familyName'],
                    forename: race_result['Driver']['givenName'],
                    dob: race_result['Driver']['dateOfBirth'],
                    nationality: race_result['Driver']['nationality'],
                    code: race_result['Driver']['code'],
                    url: race_result['Driver']['url'],
                    number: race_result['number'],
                    first_race_date: @race.date,
                    last_race_date: @race.date,
                    elo_v2: EloRatingV2::STARTING_ELO,
                    peak_elo_v2: EloRatingV2::STARTING_ELO,
                    color: Driver::CONSTRUCTOR_COLORS.fetch(constructor.constructor_ref.to_sym, "#4B0082"),
                    active: true,
                    skill: nil,
                )
                @new_drivers << driver
                all_drivers[driver.driver_ref] = driver
            end

            SeasonDriver.find_or_create_by(
                season: race.season,
                constructor: constructor,
                driver: driver,
                active: true
            )
            country = all_countries[driver.nationality]
            if country
                DriverCountry.find_or_create_by(driver: driver, country: country)
            end

            status = all_statuses[race_result['status']]
            unless status
                puts "Unknown status '#{race_result['status']}' for driver #{driver.driver_ref} in race #{@race.id}, skipping"
                next
            end

            result = RaceResult.find_or_initialize_by(
                driver: driver,
                race: @race
            )
            result.update!(
                constructor: constructor,
                status: status,
                position: race_result['position'],
                position_order: race_result['positionOrder'] || race_result['position'],
                points: race_result['points'],
                time: race_result.dig('Time', 'time') || 0,
                laps: race_result['laps'],
                milliseconds: race_result.dig('Time', 'millis'),
                fastest_lap_time: race_result.dig('FastestLap', 'Time', 'time'),
                fastest_lap_speed: race_result.dig('FastestLap', 'AverageSpeed', 'speed'),
                fastest_lap: race_result.dig('FastestLap', 'lap'),
                grid: race_result['grid'],
                number: race_result['number'],
            )
            result
        end
    end

    def standings
        standings_lists = @standings_data.dig('MRData', 'StandingsTable', 'StandingsLists')
        return unless standings_lists&.first

        all_drivers = Driver.all.index_by(&:driver_ref)

        @driver_standings = standings_lists.first['DriverStandings'].map do |driver_standing|
            driver = all_drivers[driver_standing['Driver']['driverId']]
            next unless driver

            DriverStanding.find_or_create_by(
                race: @race,
                driver: driver,
                position: driver_standing['position'],
                points: driver_standing['points'],
                wins: driver_standing['wins'],
            )
            driver.update(last_race_date: @race.date)
            UpdateDriverStanding.new(driver: driver, season: @race.season).update
        end
    end

    private

    def has_jolpica_results?
        return false unless @results_data
        races = @results_data.dig('MRData', 'RaceTable', 'Races')
        races&.first&.dig('Results')&.any? || false
    end

    def create_standings_from_results
        # Build cumulative standings from all race results in the season so far
        season = @race.season
        completed_races = season.races.joins(:race_results).distinct.where("races.round <= ?", @race.round).order(:round)

        cumulative_points = Hash.new(0.0)
        cumulative_wins = Hash.new(0)

        completed_races.each do |r|
            RaceResult.where(race: r).each do |rr|
                cumulative_points[rr.driver_id] += rr.points.to_f
                cumulative_wins[rr.driver_id] += 1 if rr.position_order == 1
            end
        end

        # Sort by points desc, then by wins desc
        sorted = cumulative_points.sort_by { |did, pts| [-pts, -cumulative_wins[did]] }

        sorted.each_with_index do |(driver_id, points), idx|
            DriverStanding.find_or_create_by(race: @race, driver_id: driver_id) do |ds|
                ds.position = idx + 1
                ds.points = points
                ds.wins = cumulative_wins[driver_id]
            end
            UpdateDriverStanding.new(driver: Driver.find(driver_id), season: season).update
        end

        puts "Created #{sorted.size} driver standings"
    end

    def create_results_from_wikipedia(wiki_results)
        @race_results = wiki_results.filter_map do |wr|
            driver = wr[:driver]
            constructor = wr[:constructor]

            # Ensure new drivers have default Elo ratings
            if driver.elo_v2.nil?
                driver.update(elo_v2: EloRatingV2::STARTING_ELO, peak_elo_v2: EloRatingV2::STARTING_ELO, first_race_date: @race.date)
            end

            SeasonDriver.find_or_create_by(
                season: @race.season,
                constructor: constructor,
                driver: driver,
                active: true
            )

            result = RaceResult.find_or_initialize_by(
                driver: driver,
                race: @race
            )
            result.update!(
                constructor: constructor,
                status: wr[:status],
                position: wr[:position],
                position_order: wr[:position_order],
                points: wr[:points],
                time: wr[:time] || 0,
                laps: wr[:laps],
                milliseconds: wr[:milliseconds],
                fastest_lap_time: wr[:fastest_lap_time],
                fastest_lap_speed: wr[:fastest_lap_speed],
                fastest_lap: wr[:fastest_lap],
                grid: wr[:grid],
                number: wr[:number],
            )

            driver.update(last_race_date: @race.date)
            result
        end
    end
end
