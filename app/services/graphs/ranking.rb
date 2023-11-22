class Graphs::Ranking
    def initialize(season:)
        @season = season
        @races = @season.races.sorted
        @drivers = @season.drivers
    end
    def season_driver_standings_data
        @series_data = @drivers.map do |driver|
            {
                data: @races.sorted.map do |race|
                    driver_standing = race.driver_standings.find_by(driver: driver)
                    if driver_standing.present?
                        {
                            name: "#{driver.forename.first}.#{driver.surname}",
                            value: driver_standing.position,
                        }
                    else
                        {
                            name: "#{driver.forename.first}.#{driver.surname}",
                        }
                    end
                end,
                type: 'line',
                name: "#{driver.forename.first}.#{driver.surname}",
                color: driver.color,
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
                data: @races.map{|race| "#{race.circuit.circuit_ref} #{race.date.strftime("%b %d, %Y")}"}
            },
            yAxis: {
                type: 'value',
                inverse: true,
                min: 1,
                max: 12,
            },
            series: @series_data,
            # toolbox: { show: true },
            # tooltip: { 
            #     trigger: "axis",
            #     position: [10, 10],
            # },
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
                type: 'category',
                inverse: true,
                interval: 1,
                maxInterval: 1,
                splitNumber: 12,
                min: 1,
                max: 12,
                axisTick: {
                    interval: 1, 
                    maxInterval: 1,
                    splitNumber: 12,
                }
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