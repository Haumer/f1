class Graphs::Champions
    def initialize(race_results:)
        @race_results = race_results.reject(&:blank?)
        @races = Race.where.not(year: 2023)
    end

    def champions_data
        @series_data = @race_results.map do |race_result|
            driver = race_result.first.driver
            data = []
            # race_result.first.race.date
            # race_result.last.race.date
            previous_races = @races.where.not(date: race_result.first.race.date..Date.today)
            following_races = @races.where.not(date:Date.new(1900,1,1)..race_result.last.race.date)
            previous_races.count.times {
                data << {
                    value: ""
                }
            }
            race_result.sort_by {|r| r.race.date}.each do |rr|
                data << {
                    name: "#{rr.race.circuit.name} - #{rr.race.date.strftime("%b %d, %Y")} - #{ordinalize(rr.position_order)} - #{rr.new_elo.round}",
                    value: rr.new_elo.round,
                }
            end
            following_races.count.times {
                data << {
                    value: ""
                }
            }
            {
                data: data,
                type: 'line',
                name: driver.surname,
                color: "#3571c6",
                smooth: true,
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                # markLine: mark_peak_elo(driver),
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
                data: @races.map{ |race| "#{race.circuit.circuit_ref} #{race.date.strftime("%b %d, %Y")}" }
            },
            yAxis: {
                type: 'value',
                min: 800,
                # max: driver.peak_elo.round + 50
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

    def mark_peak_elo(driver)
        peak_elo_race = driver.race_results.find_by(new_elo: @driver.peak_elo)
        lines = {
            label: {
                position: 'insideStartTop',
                show: true,
            },
            data: [
                {       
                    xAxis: "#{peak_elo_race.race.circuit.circuit_ref} #{peak_elo_race.race.date.strftime("%b %d, %Y")}",   
                    label: { formatter: '                                             Elo Peak' },              
                },
                {
                    type: "max",
                    label: { formatter: 'Max' },
                },
                {
                    type: "average",
                    label: { formatter: 'Average' },
                },
                {
                    type: "min",
                    label: { formatter: 'Min', position: 'insideStartBottom' },
                },
            ],
            symbol: 'none'
        }
        # @seasons.each do |season| 
        #     position = season.last_race.driver_standings.find_by(driver: @driver).position
        #     label_text = "#{season.year} #{position_in_words(position)}"
        #     lines[:data] << { 
        #         label: { 
        #             formatter: label_text,
        #             color: Race::PODIUM_COLORS[position],
        #             fontWeight: 'bold',
        #         }, 
        #         xAxis: "#{season.last_race.circuit.circuit_ref} #{season.last_race.date.strftime("%b %d, %Y")}",
        #     }
        # end
        # lines
    end

    def notable_events(driver)
        peak_elo_race = driver.race_results.find_by(new_elo: driver.peak_elo)
        points = {
            label: {
                position: 'insideStartTop',
                show: true,
            },
            data: [
                {
                    type: "max",
                    label: { formatter: '' },
                },
                {
                    type: "min",
                    label: { formatter: '' },
                },
            ],
            symbol: 'circle',
            symbolSize: 8,
        }
        # @seasons.each do |season| 
        #     last_race = season.last_race.race_results.find_by(driver:@driver)
        #     points[:data] << { 
        #         coord: [
        #             "#{season.last_race.circuit.circuit_ref} #{season.year}", 
        #             last_race.present? ? last_race.new_elo : 0
        #         ],
        #         label: { 
        #             formatter: season.last_race.driver_standings.find_by(driver: @driver).position
        #         }, 
        #     }
        # end
        driver.race_results.where(position_order: 1..3).each do |race_result|
            position = race_result.position_order
            points[:data] << { 
                coord: [
                    "#{race_result.race.circuit.circuit_ref} #{race_result.race.date.strftime("%b %d, %Y")}", 
                    race_result.new_elo
                ],
                label: { 
                    show: false,
                    color: 'white'
                },
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

    def position_in_words(position)
        case position
        when 1 then "Champion"
        else
            "#{ordinalize(position)} Place"
        end
    end

    def ordinalize(n)
        return "#{n}th" if (11..13).include?(n % 100)
      
        case n%10
        when 1 then "#{n}st"
        when 2 then "#{n}nd"
        when 3 then "#{n}rd"
        else    
            "#{n}th"
        end
    end
end