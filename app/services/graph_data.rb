class GraphData

    def initialize(options = {})
        @season = options[:season]
        @drivers = options[:drivers]
        @races = options[:races]
        @race_results = options[:race_results]
        @min_position_order = options[:min_position_order].present? ?  options[:min_position_order] : 100
        @number_of_drivers = options[:number_of_drivers].present? ? options[:number_of_drivers] : 10
        @criteria = options[:by].present? ? options[:by] : :peak_elo
        if @drivers.present?
            @last_race_date = @drivers.by_last_race_date_asc.first.last_race_date
            @first_race_date = @drivers.by_first_race_date_asc.first.first_race_date
        end
    end

    def generate
        if @drivers.present? 
            drivers_data
            graph_options(min: 800, inverse: false)
        else
            race_data
            graph_options(min: 1, inverse: true)
        end
    end

    def average
        data = @races.map do |race|
            {
                name: 'average',
                value: race.average_elo.round
            }
        end
        @series_data = {
            data: data,
            type: 'line',
            name: 'Average Elo',
            smooth: true,
            endLabel: {
                show: true,
                formatter: '{a}',
                distance: 20
            },
        }
        graph_options(min: 800, inverse: false)
    end

    def column_race
        @races = @season.races.order(round: :asc).select { |race| race.driver_standings.present? }
        @race_ids = @races.map(&:id)
        @series_data = @season.drivers.map do |driver|
            {
                data: DriverStanding.where(driver: driver, race_id: @race_ids).map do |driver_standing|
                    {
                        name: driver_standing.race.circuit.name,
                        value: driver_standing.points
                    }
                end,
                type: 'line'
            }
        end
        {
            label: {
                show: false,
            },
            xAxis: {
                max: 'category',
                data: @races.map { |race| race.circuit.circuit_ref },
            },
            yAxis: {
                type: 'value',
            },
            series: @series_data,
            legend: { show: true },
            toolbox: { show: true },
            tooltip: { 
                trigger: "axis",
                position: [10, 10],
            },
            height: "1000px",
        }
    end

    def race_results
        data = @race_results.map do |race_result|
            {
                name: race_result.driver.surname,
                value: race_result.new_elo
            }
        end
        
        @races = Race.where(id: @race_results.map(&:race).pluck(:id).uniq).order(date: :asc)
        @series_data = {
            data: data,
            type: 'line',
            name: 'Average Elo',
            smooth: true,
            endLabel: {
                show: true,
                formatter: '{a}',
                distance: 20
            },
        }
        graph_options(min: 800, inverse: false)
    end

    def drivers_data
        date_range = @first_race_date..@last_race_date
        @races = Race.where(date: date_range).sorted
        mark_lines = @drivers.count == 1 ? mark_peak_elo(@drivers.first) : {}
        @series_data = @drivers.map do |driver|
            {
                data: @races.map do |race|
                    if race.drivers.pluck(:id).include?(driver.id)
                        {
                            name: race.circuit.name,
                            value: RaceResult.find_by(driver: driver, race: race).new_elo.round
                        }
                    else
                        {
                            name: race.circuit.name
                        }
                    end
                end,
                type: 'line',
                name: driver.surname,
                color: driver.color,
                smooth: true,
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                markLine: mark_lines,
                markPoint: { data: [{
                    name: 'fixed x position',
                    yAxis: 1000,
                    x: '90%'
                },{
                    name: 'maximum',
                    type: 'max',
                    symbol: 'circle',
                    symbolSize: 8,
                    label: {
                        fontSize: 10,
                        show: false
                    }
                },    {
                    name: 'screen coordinate',
                    x: 400,
                    y: 100
                } ] }
            }
        end
    end

    def race_data
        sorted_drivers = @races.map(&:drivers).flatten.uniq.sort_by { |driver| -driver[@criteria] }.first(@number_of_drivers)
        @series_data = sorted_drivers.map do |driver|
            {
                data: @races.map do |race|
                    if race.drivers.pluck(:id).include?(driver.id)
                        position_order = RaceResult.find_by(driver: driver, race: race).position_order
                        if position_order <= @min_position_order
                            {
                                name: race.circuit.name,
                                value: position_order
                            }
                        else
                            {
                                name: race.circuit.name,
                            }
                        end
                    else
                        {
                            name: race.circuit.name
                        }
                    end
                end,
                type: 'line',
                name: driver.surname,
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
    end
    
    def graph_options(settings)
        {
            label: {
                show: false,
                position: "right"
            },
            xAxis: {
                type: 'category',
                data: @races.map{|race| "#{race.circuit.circuit_ref} #{race.date.year}"}
            },
            yAxis: {
                type: 'value',
                inverse: settings[:inverse],
                min: settings[:min],
            },
            series: @series_data,
            legend: { show: true },
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
            height: "500px",
            legend: {
                height: "1000px",
            },
        }
    end

    def mark_peak_elo(driver)
        {
            label: {
                position: 'insideStartTop',
            },
            data: [
                {
                    name: "TEST",
                    type: "max",
                },
                {           
                    xAxis: "#{driver.race_results.find_by(new_elo: driver.peak_elo).race.circuit.circuit_ref} #{driver.race_results.find_by(new_elo: driver.peak_elo).race.year }",                 
                }
            ]
        }
    end
end