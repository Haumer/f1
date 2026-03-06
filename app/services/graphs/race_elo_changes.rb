class Graphs::RaceEloChanges
    def initialize(race:)
        @race = race
        @race_results = race.race_results.includes(:driver).sort_by { |rr| rr.display_elo_diff }.reverse
    end

    def data
        drivers = @race_results.map { |rr| "#{rr.driver.forename.first}.#{rr.driver.surname}" }
        values = @race_results.map do |rr|
            diff = rr.display_elo_diff.round(1)
            {
                value: diff,
                itemStyle: { color: diff >= 0 ? "#1f883d" : "#e10600" }
            }
        end

        {
            backgroundColor: 'transparent',
            xAxis: {
                type: 'value'
            },
            yAxis: {
                type: 'category',
                data: drivers.reverse,
                axisLabel: { fontSize: 11 }
            },
            series: [
                {
                    type: 'bar',
                    data: values.reverse,
                    label: {
                        show: true,
                        position: 'right',
                        formatter: '{c}',
                        fontSize: 11
                    }
                }
            ],
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' }
            },
            grid: {
                left: '120px',
                right: '60px',
                top: '10px',
                bottom: '10px',
                containLabel: false
            },
            height: "#{[(@race_results.size * 28), 300].max}px"
        }
    end
end
