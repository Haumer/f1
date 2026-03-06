class Graphs::ActiveEloBar
    def initialize(drivers:)
        @drivers = drivers.sort_by { |d| d.display_elo || 0 }.reverse
    end

    def data
        driver_names = @drivers.map { |d| "#{d.forename.first}.#{d.surname}" }
        elo_values = @drivers.map do |d|
            constructor = d.current_constructor
            color = if constructor
                Constructor::COLORS[constructor.constructor_ref.to_sym] || d.color
            else
                d.color
            end

            {
                value: d.display_elo&.round,
                itemStyle: { color: color }
            }
        end

        peak_values = @drivers.map do |d|
            {
                value: d.display_peak_elo&.round,
                itemStyle: {
                    color: 'rgba(0,0,0,0)',
                    borderColor: '#ccc',
                    borderWidth: 1,
                    borderType: 'dashed'
                }
            }
        end

        {
            backgroundColor: 'transparent',
            yAxis: {
                type: 'category',
                data: driver_names.reverse,
                axisLabel: { fontSize: 11 }
            },
            xAxis: {
                type: 'value',
                min: Setting.use_elo_v2? ? 1500 : 800
            },
            series: [
                {
                    name: 'Current Elo',
                    type: 'bar',
                    data: elo_values.reverse,
                    label: {
                        show: true,
                        position: 'right',
                        formatter: '{c}',
                        fontSize: 11
                    },
                    barWidth: '60%',
                    z: 2
                },
                {
                    name: 'Peak Elo',
                    type: 'bar',
                    data: peak_values.reverse,
                    barGap: '-100%',
                    label: { show: false },
                    barWidth: '60%',
                    z: 1
                }
            ],
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' }
            },
            legend: {
                show: true,
                data: ['Current Elo', 'Peak Elo']
            },
            grid: {
                left: '120px',
                right: '60px',
                top: '40px',
                bottom: '10px',
                containLabel: false
            },
            height: "#{[@drivers.size * 30, 400].max}px"
        }
    end
end
