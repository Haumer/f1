class Graphs::Ranking
    def initialize(season:)
        @season = season
        @races = @season.races.sorted.includes(:circuit)
        @drivers = @season.drivers.distinct
        all_standings = DriverStanding.where(race: @races, driver: @drivers).to_a

        # DriverStanding data is sparse — often only point-scorers are listed.
        # Supplement with RaceResult data: any driver who raced but has no
        # standing gets 0 points and is ranked after the listed drivers.
        race_results_by_race = RaceResult.where(race: @races, driver: @drivers)
                                         .group_by(&:race_id)
        existing_by_race = all_standings.group_by(&:race_id)

        @races.each do |race|
            existing = existing_by_race[race.id] || []
            existing_driver_ids = existing.map(&:driver_id).to_set
            last_position = existing.size

            results = race_results_by_race[race.id] || []
            results.sort_by(&:position_order).each do |rr|
                next if existing_driver_ids.include?(rr.driver_id)
                last_position += 1
                synth = DriverStanding.new(
                    race_id: race.id, driver_id: rr.driver_id,
                    points: 0, wins: 0, position: last_position
                )
                all_standings << synth
            end
        end

        # Fill in nil positions: assign after the last real position,
        # ordered by race result finish position to break ties
        standings_by_race = all_standings.group_by(&:race_id)
        standings_by_race.each do |race_id, standings|
            with_pos = standings.select(&:position)
            without_pos = standings.reject(&:position)
            next if without_pos.empty?

            next_position = (with_pos.map(&:position).max || 0) + 1
            # Order nil-position drivers by their race result finish
            result_order = (race_results_by_race[race_id] || []).each_with_object({}) do |rr, h|
                h[rr.driver_id] = rr.position_order || 999
            end
            without_pos.sort_by { |ds| result_order[ds.driver_id] || 999 }.each do |ds|
                ds.position = next_position
                next_position += 1
            end
        end

        @standings_lookup = all_standings.group_by { |ds| [ds.race_id, ds.driver_id] }
        @constructor_by_driver = SeasonDriver.where(season: @season, driver: @drivers)
                                             .includes(:constructor)
                                             .order(:id)
                                             .group_by(&:driver_id)
                                             .transform_values { |sds| sds.last.constructor }
    end

    def season_driver_standings_data
        @series_data = @drivers.map do |driver|
            driver_name = "#{driver.forename.first}.#{driver.surname}"
            constructor = @constructor_by_driver[driver.id]
            team_color = constructor && Constructor::COLORS[constructor.constructor_ref.to_sym]
            line_color = team_color || driver.color || '#888888'

            raw_data = @races.map do |race|
                driver_standing = @standings_lookup[[race.id, driver.id]]&.first
                if driver_standing&.position
                    { name: driver_name, value: driver_standing.position }
                end
            end

            # Forward-fill mid-season gaps (carry last known position)
            forward_fill!(raw_data, driver_name)

            {
                data: raw_data,
                type: 'line',
                name: driver_name,
                color: line_color,
                emphasis: { focus: 'series' },
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20,
                },
                lineStyle: { width: 2 },
                smooth: true,
                connectNulls: true,
                symbolSize: 8,
            }
        end

        max_position = @standings_lookup.values.flatten.filter_map(&:position).max || 20

        {
            backgroundColor: 'transparent',
            label: {
                show: false,
                position: "right"
            },
            grid: {
                right: 120,
            },
            xAxis: {
                type: 'category',
                data: @races.map { |race| "#{race.circuit.circuit_ref} #{race.date.strftime("%b %d, %Y")}" }
            },
            yAxis: {
                type: 'value',
                inverse: true,
                min: 1,
                max: max_position,
            },
            series: @series_data,
            dataZoom: [
                {
                    id: 'dataZoomX',
                    type: 'slider',
                    xAxisIndex: [0],
                    filterMode: 'filter'
                }
            ],
            height: "500px",
            legend: {
                type: 'scroll',
                itemGap: 4,
            },
        }
    end

    private

    # Forward-fill: carry last known position through mid-season nil gaps
    def forward_fill!(data, driver_name)
        last_known = nil
        data.each_with_index do |entry, i|
            if entry
                last_known = entry[:value]
            elsif last_known
                data[i] = { name: driver_name, value: last_known }
            end
        end
    end
end
