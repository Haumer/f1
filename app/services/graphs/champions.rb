class Graphs::Champions
    def initialize(race_results:)
        @race_results = race_results.reject(&:blank?)
        @races = Race.where.not(year: Date.current.year).sorted.includes(:circuit)
        @race_ids = @races.map(&:id)
        @race_index = @race_ids.each_with_index.to_h
        @new_elo_col = Setting.elo_column(:new_elo).to_sym
    end

    def champions_data
        @series_data = @race_results.filter_map do |race_result|
            next if race_result.blank?

            driver = race_result.first&.driver
            next unless driver

            sorted = race_result.sort_by { |r| r.race.date }
            first_idx = @race_index[sorted.first.race_id]
            last_idx = @race_index[sorted.last.race_id]
            next unless first_idx && last_idx

            data = Array.new(@race_ids.size) { { value: "" } }
            sorted.each do |rr|
                idx = @race_index[rr.race_id]
                next unless idx
                elo_val = rr.send(@new_elo_col)
                next unless elo_val
                data[idx] = {
                    name: "#{rr.race.circuit.name} - #{rr.race.date.strftime("%b %d, %Y")} - #{ordinalize(rr.position_order)} - #{elo_val.round}",
                    value: elo_val.round,
                }
            end

            {
                data: data,
                type: 'line',
                name: driver.surname,
                color: driver.color,
                smooth: true,
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                markPoint: notable_events(driver)
            }
        end

        {
            label: {
                show: false,
                position: "right"
            },
            xAxis: {
                type: 'category',
                data: @races.map { |race| "#{race.circuit.circuit_ref} #{race.date.strftime("%b %d, %Y")}" }
            },
            yAxis: {
                type: 'value',
                min: Setting.use_elo_v2? ? 1500 : 800,
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
                    filterMode: 'filter'
                }
            ],
            smoothMonotone: 'y'
        }
    end

    private

    def notable_events(driver)
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
        driver.race_results.where(position_order: 1..3).includes(race: :circuit).each do |race_result|
            position = race_result.position_order
            points[:data] << {
                coord: [
                    "#{race_result.race.circuit.circuit_ref} #{race_result.race.date.strftime("%b %d, %Y")}",
                    race_result.send(@new_elo_col)
                ],
                label: { show: false, color: 'white' },
                value: race_result.position_order,
                symbol: 'circle',
                itemStyle: {
                    color: Race::PODIUM_COLORS[position],
                    borderWidth: 1,
                    borderColor: 'black'
                },
                symbolSize: 6
            }
        end
        points
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
