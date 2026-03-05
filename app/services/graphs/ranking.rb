class Graphs::Ranking
    TOP_N_VISIBLE = 10  # show top 10 by final standings, rest togglable

    def initialize(season:)
        @season = season
        @races = @season.races.sorted.includes(:circuit)
        @drivers = @season.drivers.distinct
        all_standings = DriverStanding.where(race: @races, driver: @drivers).to_a

        # Fill in nil positions by ranking drivers by points per race
        standings_by_race = all_standings.group_by(&:race_id)
        standings_by_race.each do |_race_id, standings|
            sorted = standings.sort_by { |ds| [-(ds.points || 0), -(ds.wins || 0)] }
            sorted.each_with_index do |ds, idx|
                ds.position ||= idx + 1
            end
        end

        @standings_lookup = all_standings.group_by { |ds| [ds.race_id, ds.driver_id] }
        @constructor_by_driver = SeasonDriver.where(season: @season, driver: @drivers)
                                             .includes(:constructor)
                                             .order(:id)
                                             .group_by(&:driver_id)
                                             .transform_values { |sds| sds.last.constructor }

        # Determine final standings position per driver (last race with data)
        last_race = @races.last
        @final_positions = if last_race
            (standings_by_race[last_race.id] || [])
                .sort_by { |ds| ds.position || 999 }
                .each_with_object({}) { |ds, h| h[ds.driver_id] = ds.position }
        else
            {}
        end
    end

    def season_driver_standings_data
        legend_selected = {}

        @series_data = @drivers.map do |driver|
            driver_name = "#{driver.forename.first}.#{driver.surname}"
            constructor = @constructor_by_driver[driver.id]
            team_color = constructor && Constructor::COLORS[constructor.constructor_ref.to_sym]
            line_color = team_color || driver.color || '#888888'

            final_pos = @final_positions[driver.id]
            legend_selected[driver_name] = final_pos.present? && final_pos <= TOP_N_VISIBLE

            {
                data: @races.map do |race|
                    driver_standing = @standings_lookup[[race.id, driver.id]]&.first
                    if driver_standing&.position
                        { name: driver_name, value: driver_standing.position }
                    end
                end,
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

        visible_positions = @final_positions.values.select { |p| p <= TOP_N_VISIBLE }
        max_position = (visible_positions.max || TOP_N_VISIBLE) + 2

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
                selected: legend_selected,
            },
        }
    end
end
