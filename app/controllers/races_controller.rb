class RacesController < ApplicationController

    def show
        @race = Race.includes(
            race_results: { driver: [:countries, { season_drivers: :constructor }], constructor: [], status: [] },
            driver_standings: []
        ).find(params[:id])
        @previous_race = @race.previous_race
        @next_race = @race.next_race
        set_race_winner_accent(@race)

        results = @race.race_results.to_a
        @grid_size = results.size
        @biggest_gainer = results.max_by(&:display_elo_diff)
        @biggest_loser = results.min_by(&:display_elo_diff)
        new_elo_col = Setting.elo_column(:new_elo).to_sym
        @highest_elo_rr = results.max_by { |rr| rr.send(new_elo_col) || 0 }
        @dnf_count = results.count { |rr| rr.status&.status_type != "Finished" && !rr.status&.status_type.to_s.downcase.include?("lap") }

        # Pre-index driver standings to avoid N+1 in view
        @standings_by_driver = @race.driver_standings.index_by(&:driver_id)

        # Circuit kings
        @circuit_kings = DriverBadge.where("key = ?", "circuit_king_#{@race.circuit_id}")
                                    .includes(:driver).order(Arel.sql("CASE tier WHEN 'gold' THEN 0 WHEN 'silver' THEN 1 WHEN 'bronze' THEN 2 ELSE 3 END"))

        # Pre-index constructors per driver for this season to avoid N+1
        season = @race.season
        driver_ids = results.map(&:driver_id)
        season_drivers = SeasonDriver.where(season: season, driver_id: driver_ids).includes(:constructor)
        @constructor_by_driver = season_drivers.each_with_object({}) do |sd, h|
            h[sd.driver_id] = sd.constructor
        end
    end

    def index
        if params[:search].present? && params[:search][:date].present?
            begin
                search_date = Date.parse(params[:search][:date])
            rescue ArgumentError
                search_date = Date.new(1930,1,1)
            end
            @races = Race.where(date: search_date..Date.today).sorted_by_most_recent.includes(race_results: { driver: :countries, constructor: [] }, circuit: [])
        else
            @races = Race.where(year: 2000..Date.current.year).sorted_by_most_recent.includes(race_results: { driver: :countries, constructor: [] }, circuit: [])
        end
        @seasons_by_year = Season.all.index_by { |s| s.year.to_i }
    end

    def highest_elo
        new_elo_col = Setting.elo_column(:new_elo)
        @race_results = RaceResult.joins(:race)
            .where.not(new_elo_col => nil)
            .order(new_elo_col => :desc)
            .limit(100)
            .includes(:driver, :constructor, race: :circuit)
    end

    def podiums
        @drivers = Driver.where("podiums > 0").includes(:countries).order(podiums: :desc).limit(50)
    end

    def winners
        standings = Driver.champion_standings.to_a
        champion_drivers = standings.map(&:driver).uniq
        champion_ids = champion_drivers.map(&:id)

        # Batch-load all race results for champions to avoid N+1
        all_results = RaceResult.where(driver_id: champion_ids)
                                .includes(race: :circuit)
                                .group_by(&:driver_id)

        @champ_race_results = champion_drivers.map do |driver|
            all_results[driver.id] || []
        end

        # Championship count data for table and chart
        @champion_data = standings.group_by(&:driver).map do |driver, titles|
            years = titles.map { |t| t.race.season.year }.sort
            [driver, { count: titles.size, years: years }]
        end.sort_by { |_, d| -d[:count] }
    end
end
