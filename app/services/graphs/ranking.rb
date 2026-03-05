class Graphs::Ranking
    def initialize(season:)
        @season = season
        @races = @season.races.sorted.includes(:circuit)
        @drivers = @season.drivers.distinct
        @standings_lookup = DriverStanding.where(race: @races, driver: @drivers)
                                         .group_by { |ds| [ds.race_id, ds.driver_id] }
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
            {
                data: @races.map do |race|
                    driver_standing = @standings_lookup[[race.id, driver.id]]&.first
                    if driver_standing&.position
                        { name: driver_name, value: driver_standing.position }
                    else
                        '-'
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
                connectNulls: false,
                symbolSize: 6,
            }
        end

        max_position = @standings_lookup.values.flatten.filter_map(&:position).max || 20

        {
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
end
