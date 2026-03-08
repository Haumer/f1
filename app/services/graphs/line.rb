class Graphs::Line
    def initialize(driver:)
        @driver = driver
        @new_elo_col = :new_elo_v2
        date_range = @driver.first_race_date..@driver.last_race_date
        @races = Race.where(date: date_range).sorted.includes(:circuit)
        @seasons = @driver.seasons.where.not(year: Date.current.year.to_s)
                         .includes(races: :circuit)
        @race_results_by_race = @driver.race_results.where(race: @races)
                                       .includes(race: :circuit)
                                       .index_by(&:race_id)

        # Batch-load standings for all season-end races to avoid N+1
        season_race_ids = @seasons.flat_map { |s| s.races.map(&:id) }
        @driver_standings_by_race = @driver.driver_standings
                                          .where(race_id: season_race_ids)
                                          .index_by(&:race_id)
    end

    def driver_data
        @series_data = [
            {
                data: @races.map do |race|
                    race_result = @race_results_by_race[race.id]
                    if race_result && race_result.send(@new_elo_col)
                        {
                            name: "#{race.circuit.name} - #{race.date.strftime("%b %d, %Y")} - #{ordinalize(race_result.position_order)} - #{race_result.send(@new_elo_col).round}",
                            value: race_result.send(@new_elo_col).round,
                        }
                    else
                        {
                            name: race.circuit.name
                        }
                    end
                end,
                type: 'line',
                name: @driver.surname,
                color: @driver.color,
                smooth: true,
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                markLine: mark_peak_elo,
                markPoint: notable_events
            }
        ]
        # Calculate dataZoom start to show ~last 8 years of career
        total = @races.size
        zoom_start = if total > 0
            career_end = @driver.last_race_date || Date.current
            cutoff_date = career_end - 8.years
            first_visible = @races.index { |r| r.date >= cutoff_date } || 0
            (first_visible.to_f / total * 100).round(1)
        else
            0
        end

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
                min: [(@driver.display_lowest_elo || 800).round - 50, 1500].min,
                max: (@driver.display_peak_elo || 1200).round + 50
            },
            series: @series_data,
            legend: { show: true },
            toolbox: { show: true },
            tooltip: {
                trigger: "axis",
                formatter: '{b}',
                position: [10, 10],
            },
            height: "700px",
            dataZoom: [
                {
                    id: 'dataZoomX',
                    type: 'slider',
                    xAxisIndex: [0],
                    filterMode: 'filter',
                    start: zoom_start,
                    end: 100
                }
            ],
            smoothMonotone: 'y'
        }
    end

    private

    def race_x_label(race)
        "#{race.circuit.circuit_ref} #{race.date.strftime("%b %d, %Y")}"
    end

    def mark_peak_elo
        peak_elo_race = @driver.display_peak_elo_race_result
        return { data: [] } unless peak_elo_race

        lines = {
            label: {
                position: 'insideStartTop',
                show: true,
            },
            data: [
                {
                    xAxis: race_x_label(peak_elo_race.race),
                    label: { formatter: '                                             Elo Peak' },
                },
                { type: "max", label: { formatter: 'Max' } },
                { type: "average", label: { formatter: 'Average' } },
                { type: "min", label: { formatter: 'Min', position: 'insideStartBottom' } },
            ],
            symbol: 'none'
        }

        @seasons.each do |season|
            last = season_last_race(season)
            next unless last

            latest = season_latest_race(season)
            standing = @driver_standings_by_race[latest&.id]
            next unless standing

            position = standing.position
            lines[:data] << {
                label: {
                    formatter: "#{season.year} #{position_in_words(position)}",
                    color: Race::PODIUM_COLORS[position],
                    fontWeight: 'bold',
                },
                xAxis: race_x_label(last),
            }
        end
        lines
    end

    def notable_events
        points = {
            label: {
                position: 'insideStartTop',
                show: true,
            },
            data: [
                { type: "max", label: { formatter: '' } },
                { type: "min", label: { formatter: '' } },
            ],
            symbol: 'circle',
            symbolSize: 8,
        }

        @seasons.each do |season|
            last = season_last_race(season)
            next unless last

            last_race_result = @race_results_by_race[last.id]
            elo_val = last_race_result&.send(@new_elo_col)
            next unless elo_val

            latest = season_latest_race(season)
            standing = @driver_standings_by_race[latest&.id]

            points[:data] << {
                coord: [race_x_label(last), elo_val],
                label: { formatter: standing&.position },
            }
        end

        @driver.race_results.where(position_order: 1..3).includes(race: :circuit).each do |race_result|
            elo_point = race_result.send(@new_elo_col)
            next unless elo_point
            position = race_result.position_order
            points[:data] << {
                coord: [race_x_label(race_result.race), elo_point],
                label: { show: false, color: 'white' },
                value: race_result.position_order,
                symbol: 'circle',
                itemStyle: {
                    color: Race::PODIUM_COLORS[position],
                    borderWidth: 1,
                    borderColor: 'black'
                },
                symbolSize: 8
            }
        end
        points
    end

    def season_last_race(season)
        season.races.select(&:season_end).first || season.races.max_by(&:round)
    end

    def season_latest_race(season)
        season.races.select { |r| @driver_standings_by_race.key?(r.id) }.max_by(&:round)
    end

    def position_in_words(position)
        case position
        when 1 then "Champion"
        else "#{ordinalize(position)} Place"
        end
    end

    def ordinalize(n)
        return "#{n}th" if (11..13).include?(n % 100)

        case n % 10
        when 1 then "#{n}st"
        when 2 then "#{n}nd"
        when 3 then "#{n}rd"
        else "#{n}th"
        end
    end
end
