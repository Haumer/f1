class Graphs::SeasonElo
    include Graphs::Base

    def initialize(season:, top_n: nil)
        @season = season
        @races = @season.races.sorted.includes(:circuit)
        if top_n
            elo_col = Setting.elo_column(:elo)
            driver_ids = @season.drivers.distinct.pluck(:id)
            @drivers = Driver.where(id: driver_ids).where.not(elo_col => nil).order(elo_col => :desc).limit(top_n)
        else
            @drivers = @season.drivers.distinct
        end
        @race_results_lookup = RaceResult.where(race: @races, driver: @drivers)
                                         .group_by { |rr| [rr.race_id, rr.driver_id] }
        @constructor_by_driver = SeasonDriver.where(season: @season, driver: @drivers)
                                             .includes(:constructor)
                                             .order(:id)
                                             .group_by(&:driver_id)
                                             .transform_values { |sds| sds.last.constructor }
    end

    def season_elo_data
        new_elo_col = Setting.elo_column(:new_elo).to_sym
        old_elo_col = Setting.elo_column(:old_elo).to_sym
        @series_data = @drivers.map do |driver|
            driver_name = "#{driver.forename.first}.#{driver.surname}"
            constructor = @constructor_by_driver[driver.id]
            team_color = constructor && Constructor::COLORS[constructor.constructor_ref.to_sym]

            # Build data with carry-forward: if a driver missed a race,
            # use their old_elo from the next race they did participate in
            # (which equals their Elo going into that weekend, unchanged).
            raw = @races.map do |race|
                rr = @race_results_lookup[[race.id, driver.id]]&.first
                elo_val = rr&.send(new_elo_col)
                old_val = rr&.send(old_elo_col)
                { name: driver_name, new_elo: elo_val&.round, old_elo: old_val&.round }
            end

            # Forward-fill gaps: carry new_elo from last race through missed races
            last_elo = nil
            filled = raw.map do |entry|
                if entry[:new_elo]
                    last_elo = entry[:new_elo]
                    { name: entry[:name], value: entry[:new_elo] }
                elsif last_elo
                    { name: entry[:name], value: last_elo }
                end
            end

            {
                data: filled,
                type: 'line',
                name: driver_name,
                color: team_color || driver.color,
                emphasis: { focus: 'series' },
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                smooth: true,
                connectNulls: true,
                symbolSize: 8,
            }
        end

        elo_values = @race_results_lookup.values.flatten.filter_map { |rr| rr.send(new_elo_col)&.round }
        min_elo = elo_values.min || 800
        max_elo = elo_values.max || 2000

        {
            backgroundColor: 'transparent',
            label: {
                show: false,
                position: "right"
            },
            xAxis: {
                type: 'category',
                data: @races.map { |race| race_x_label(race) }
            },
            yAxis: {
                type: 'value',
                min: (min_elo - 50),
                max: (max_elo + 50),
            },
            series: @series_data,
            dataZoom: data_zoom_slider,
            height: "400px",
            legend: {
                type: 'plain',
                itemGap: 2,
            },
        }
    end
end
