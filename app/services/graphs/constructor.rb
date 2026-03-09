class Graphs::Constructor
    include Graphs::Base

    MIN_RESULTS_TO_INCLUDE = 3   # minimum to appear in legend at all
    RECENT_WINDOW = 8.years      # show drivers active within this window by default

    def initialize(constructor:)
        @constructor = constructor
        @new_elo_col = Setting.elo_column(:new_elo).to_sym
        @race_results = constructor.race_results.includes(race: :circuit, driver: [])
                                    .sort_by { |rr| rr.race.date }
        @races = @race_results.map(&:race).uniq.sort_by(&:date)
        @drivers = @race_results.map(&:driver).uniq
        @results_by_race_driver = @race_results.group_by { |rr| [rr.race_id, rr.driver_id] }
        @results_by_driver = @race_results.group_by(&:driver_id)
        @cutoff_date = Date.current - RECENT_WINDOW
    end

    def data
        legend_selected = {}

        series = @drivers.filter_map do |driver|
            driver_results = @results_by_driver[driver.id] || []
            next if driver_results.size < MIN_RESULTS_TO_INCLUDE

            driver_label = "#{driver.forename&.first}.#{driver.surname}"

            # Drivers unticked by default — only team Elo line is shown
            legend_selected[driver_label] = false

            race_data = @races.map do |race|
                rr = @results_by_race_driver[[race.id, driver.id]]&.first
                elo_val = rr&.send(@new_elo_col)
                if elo_val
                    {
                        name: "#{race.circuit.name} - #{race.date.strftime("%b %d, %Y")} - #{driver_label} - #{elo_val.round}",
                        value: elo_val.round
                    }
                else
                    { value: "" }
                end
            end

            {
                data: race_data,
                type: 'line',
                name: driver_label,
                color: driver.color,
                smooth: true,
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                symbolSize: 0
            }
        end

        # Sort series: highlighted (recent) drivers first, then alphabetical
        series.sort_by! { |s| [legend_selected[s[:name]] ? 0 : 1, s[:name]] }

        # Add constructor Elo V2 line (always visible, thicker)
        constructor_elo_data = @races.map do |race|
            rr = @race_results.find { |r| r.race_id == race.id && r.new_constructor_elo_v2.present? }
            if rr
                {
                    name: "#{race.circuit.name} - #{race.date.strftime("%b %d, %Y")} - #{@constructor.name} - #{rr.new_constructor_elo_v2.round}",
                    value: rr.new_constructor_elo_v2.round
                }
            else
                { value: "" }
            end
        end

        has_constructor_elo = constructor_elo_data.any? { |d| d[:value] != "" }
        if has_constructor_elo
            legend_selected[@constructor.name] = true
            series.unshift({
                data: constructor_elo_data,
                type: 'line',
                name: @constructor.name,
                color: Constructor::COLORS[@constructor.constructor_ref&.to_sym] || '#666',
                smooth: true,
                lineStyle: { width: 3 },
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                symbolSize: 0
            })
        end

        # Pre-scroll to last 8 years
        total = @races.size
        zoom_start = if total > 0
            cutoff_date = Date.current - 8.years
            first_visible = @races.index { |r| r.date >= cutoff_date } || 0
            (first_visible.to_f / total * 100).round(1)
        else
            0
        end

        {
            backgroundColor: 'transparent',
            xAxis: {
                type: 'category',
                data: @races.map { |r| race_x_label(r) }
            },
            yAxis: {
                type: 'value',
                min: 1500
            },
            series: series,
            legend: {
                show: true,
                type: 'scroll',
                selected: legend_selected
            },
            toolbox: { show: true },
            tooltip: line_tooltip,
            height: "600px",
            dataZoom: data_zoom_slider(start: zoom_start),
            smoothMonotone: 'y'
        }
    end
end
