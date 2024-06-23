class Graphs::Line
    def initialize(driver:)
        @driver = driver
        @last_race_date = @driver.last_race_date
        @first_race_date = @driver.first_race_date
        date_range = @first_race_date..@last_race_date
        @races = Race.where(date: date_range).sorted
        @seasons = @driver.seasons.where.not(year: 2024)
    end

    def driver_data
        @series_data = [
            {
                data: @races.sorted.map do |race|
                    race_result = RaceResult.find_by(driver: @driver, race: race)
                    if race.drivers.pluck(:id).include?(@driver.id)
                        {
                            name: "#{race.circuit.name} - #{race.date.strftime("%b %d, %Y")} - #{ordinalize(race_result.position_order)} - #{race_result.new_elo.round}",
                            value: race_result.new_elo.round,
                        }
                    else
                        {
                            name: race.circuit.name
                        }
                    end
                end,
                type: 'line',
                name: @driver.surname,
                color: "#3571c6",
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
                min: 800,
                max: @driver.peak_elo.round + 50
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

    def mark_peak_elo
        peak_elo_race = @driver.race_results.find_by(new_elo: @driver.peak_elo)
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
        @seasons.each do |season| 
            position = season.latest_race.driver_standings.find_by(driver: @driver).position
            label_text = "#{season.year} #{position_in_words(position)}"
            lines[:data] << { 
                label: { 
                    formatter: label_text,
                    color: Race::PODIUM_COLORS[position],
                    fontWeight: 'bold',
                }, 
                xAxis: "#{season.last_race.circuit.circuit_ref} #{season.last_race.date.strftime("%b %d, %Y")}",
            }
        end
        lines
    end

    def notable_events
        peak_elo_race = @driver.race_results.find_by(new_elo: @driver.peak_elo)
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
        @seasons.each do |season| 
            last_race = season.last_race.race_results.find_by(driver:@driver)
            points[:data] << { 
                coord: [
                    "#{season.last_race.circuit.circuit_ref} #{season.year}", 
                    last_race.present? ? last_race.new_elo : 0
                ],
                label: { 
                    formatter: season.latest_race.driver_standings.find_by(driver: @driver).position
                }, 
            }
        end
        @driver.race_results.where(position_order: 1..3).each do |race_result|
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
                symbolSize: 8
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