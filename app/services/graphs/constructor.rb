class Graphs::Constructor
    def initialize(constructor:)
        @constructor = constructor
        @new_elo_col = Setting.elo_column(:new_elo).to_sym
        @race_results = constructor.race_results.includes(race: :circuit, driver: [])
                                    .sort_by { |rr| rr.race.date }
        @races = @race_results.map(&:race).uniq.sort_by(&:date)
        @drivers = @race_results.map(&:driver).uniq
        @results_by_race_driver = @race_results.group_by { |rr| [rr.race_id, rr.driver_id] }
    end

    def data
        series = @drivers.map do |driver|
            driver_results = @race_results.select { |rr| rr.driver_id == driver.id }
            next if driver_results.size < 3

            race_data = @races.map do |race|
                rr = @results_by_race_driver[[race.id, driver.id]]&.first
                elo_val = rr&.send(@new_elo_col)
                if elo_val
                    {
                        name: "#{race.circuit.name} - #{race.date.strftime("%b %d, %Y")} - #{driver.forename.first}.#{driver.surname} - #{elo_val.round}",
                        value: elo_val.round
                    }
                else
                    { value: "" }
                end
            end

            {
                data: race_data,
                type: 'line',
                name: "#{driver.forename.first}.#{driver.surname}",
                color: driver.color,
                smooth: true,
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                symbolSize: 0
            }
        end.compact

        {
            xAxis: {
                type: 'category',
                data: @races.map { |r| "#{r.circuit.circuit_ref} #{r.date.strftime("%b %d, %Y")}" }
            },
            yAxis: {
                type: 'value',
                min: Setting.use_elo_v2? ? 1500 : 800
            },
            series: series,
            legend: { show: true },
            toolbox: { show: true },
            tooltip: {
                trigger: "axis",
                formatter: '{b}',
                position: [10, 10]
            },
            height: "500px",
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
end
