class Graphs::Ranking
    def initialize(season:)
        @season = season
        @races = @season.races.sorted.includes(:circuit)
        @drivers = @season.drivers.distinct
        all_standings = DriverStanding.where(race: @races, driver: @drivers).to_a

        # Build lookup of existing standings
        standings_by_race = all_standings.group_by(&:race_id)

        # Fill in nil positions by ranking drivers by points per race
        standings_by_race.each do |_race_id, standings|
            sorted = standings.sort_by { |ds| [-(ds.points || 0), -(ds.wins || 0)] }
            sorted.each_with_index do |ds, idx|
                ds.position ||= idx + 1
            end
        end

        # Synthesize missing standings for early races.
        # If a driver has standings later but not for an early race,
        # they had 0 points — rank them after all listed drivers.
        driver_ids_with_standings = all_standings.map(&:driver_id).uniq
        @races.each do |race|
            existing = standings_by_race[race.id] || []
            existing_driver_ids = existing.map(&:driver_id)
            last_position = existing.map(&:position).compact.max || 0

            missing_driver_ids = driver_ids_with_standings - existing_driver_ids
            missing_driver_ids.each do |did|
                last_position += 1
                synth = DriverStanding.new(race_id: race.id, driver_id: did, points: 0, wins: 0, position: last_position)
                all_standings << synth
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
