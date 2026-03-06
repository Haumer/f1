class Graphs::ChampionshipCount
    def initialize(champion_data:)
        @champion_data = champion_data.sort_by { |_driver, data| -data[:count] }
    end

    def data
        driver_names = @champion_data.map { |driver, _| "#{driver.forename.first}.#{driver.surname}" }
        values = @champion_data.map do |driver, d|
            {
                value: d[:count],
                itemStyle: { color: driver.color }
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
                minInterval: 1
            },
            series: [
                {
                    type: 'bar',
                    data: values.reverse,
                    label: {
                        show: true,
                        position: 'right',
                        formatter: '{c}',
                        fontSize: 12,
                        fontWeight: 'bold'
                    }
                }
            ],
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' }
            },
            grid: {
                left: '140px',
                right: '50px',
                top: '10px',
                bottom: '10px',
                containLabel: false
            },
            height: "#{[@champion_data.size * 28, 300].max}px"
        }
    end
end
