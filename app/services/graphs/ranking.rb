class Graphs::Ranking
    def initialize(driver_driver_standings:)
        @driver_driver_standings = driver_driver_standings
    end

    def driver_standings_data

        @series_data = @driver_driver_standings.map do |driver_driver_standings|
            {
                data: driver_driver_standings.map do |driver_standing|
                    {
                        name: driver_standing.driver,
                        value: driver_standing.position
                    }
                end,
                type: 'line',
                name: driver_driver_standings.present? ? driver_driver_standings.first.driver.surname : '',
                color: driver_driver_standings.present? ? driver_driver_standings.first.driver.color : '',
                emphasis: {
                    focus: 'series'
                },
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                smooth: true,
                symbolSize: 20,
            }
        end
        {
            label: {
                show: false,
                position: "right"
            },
            xAxis: {
                type: 'category',
                # data: @races.map{|race| "#{race.circuit.circuit_ref} #{race.date.year}"}
            },
            yAxis: {
                type: 'value',
                inverse: true,
                min: 1,
                max: 12,
            },
            series: @series_data,
            toolbox: { show: true },
            tooltip: { 
                trigger: "axis",
                position: [10, 10],
            },
            dataZoom: [
                {
                    id: 'dataZoomX',
                    type: 'slider',
                    xAxisIndex: [0],
                    filterMode: 'filter'
                }
            ],
            start: 0,
            end: 50,
            maxSpan: [0,50],
            minSpan: [0,20],
            height: "400px",
            legend: {
                height: "1000px",
                type: 'plain',
                selectorLabel: {show: true, rotate: '90',},
                itemGap: 2,
            },
            emphasis: {
                selectorLabel: {show: false}
            },
            selector: false
        }
    end
end