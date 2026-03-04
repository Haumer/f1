class Graphs::Compare
    def initialize(drivers:)
        @drivers = drivers
        @new_elo_col = Setting.elo_column(:new_elo).to_sym
        min_date = @drivers.map(&:first_race_date).compact.min
        max_date = @drivers.map(&:last_race_date).compact.max
        return unless min_date && max_date

        @races = Race.where(date: min_date..max_date).sorted.includes(:circuit)
        @race_results_by_driver = {}
        @drivers.each do |driver|
            @race_results_by_driver[driver.id] = driver.race_results
                .where(race: @races)
                .includes(race: :circuit)
                .index_by(&:race_id)
        end
    end

    def data
        return {} unless @races&.any?

        series = @drivers.map do |driver|
            results_index = @race_results_by_driver[driver.id]
            {
                data: @races.map do |race|
                    rr = results_index[race.id]
                    elo_val = rr&.send(@new_elo_col)
                    if elo_val
                        {
                            name: "#{driver.forename.first}.#{driver.surname} - #{race.circuit.name} - #{elo_val.round}",
                            value: elo_val.round
                        }
                    else
                        { value: "" }
                    end
                end,
                type: 'line',
                name: "#{driver.forename.first}.#{driver.surname}",
                color: driver.color,
                smooth: true,
                endLabel: { show: true, formatter: '{a}', distance: 20 },
                symbolSize: 0
            }
        end

        {
            xAxis: { type: 'category', data: @races.map { |r| "#{r.circuit.circuit_ref} #{r.date.strftime("%b %d, %Y")}" } },
            yAxis: { type: 'value', min: Setting.use_elo_v2? ? 1500 : 800 },
            series: series,
            legend: { show: true },
            toolbox: { show: true },
            tooltip: { trigger: "axis", formatter: '{b}', position: [10, 10] },
            height: "600px",
            dataZoom: [{ id: 'dataZoomX', type: 'slider', xAxisIndex: [0], filterMode: 'filter' }],
            smoothMonotone: 'y'
        }
    end
end
