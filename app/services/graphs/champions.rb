class Graphs::Champions
    include Graphs::Base

    def initialize(race_results:, year_range: nil)
        @race_results = race_results.reject(&:blank?)
        @year_range = year_range
        races = Race.sorted.includes(:circuit)
        races = races.where(year: year_range) if year_range
        @races = races
        @race_ids = @races.map(&:id)
        @race_index = @race_ids.each_with_index.to_h
        @race_id_set = @race_ids.to_set
        @new_elo_col = Setting.elo_column(:new_elo).to_sym
    end

    def champions_data
        # Batch-load podium results for all drivers to avoid N+1 in notable_events
        all_driver_ids = @race_results.filter_map { |rr| rr&.first&.driver_id }.uniq
        @podium_results_by_driver = RaceResult
          .where(driver_id: all_driver_ids, race_id: @race_ids, position_order: 1..3)
          .includes(race: :circuit)
          .group_by(&:driver_id)

        @series_data = @race_results.filter_map do |race_result|
            next if race_result.blank?

            driver = race_result.first&.driver
            next unless driver

            sorted = race_result.select { |r| @race_index.key?(r.race_id) }.sort_by { |r| r.race.date }
            next if sorted.empty?

            data = Array.new(@race_ids.size) { { value: "" } }
            sorted.each do |rr|
                idx = @race_index[rr.race_id]
                next unless idx
                elo_val = rr.send(@new_elo_col)
                next unless elo_val
                data[idx] = {
                    name: "#{rr.race.circuit.name} - #{rr.race.date.strftime("%b %d, %Y")} - #{ordinalize(rr.position_order)} - #{elo_val.round}",
                    value: elo_val.round,
                }
            end

            # Final Elo for end label
            final_elo = data.reverse.find { |d| d[:value].is_a?(Numeric) }&.dig(:value)

            {
                data: data,
                type: 'line',
                name: driver.surname,
                color: driver.color,
                smooth: true,
                endLabel: {
                    show: true,
                    formatter: final_elo ? js_function("function(p) { return p.seriesName + ' (' + #{final_elo} + ')'; }") : '{a}',
                    distance: 20
                },
                markPoint: notable_events(driver)
            }
        end

        {
            backgroundColor: 'transparent',
            label: {
                show: false,
                position: "right"
            },
            xAxis: {
                type: 'category',
                data: @races.map { |race| race_x_label(race) }
            },
            yAxis: {
                type: 'value',
                min: 1500,
            },
            series: @series_data,
            legend: { show: true },
            toolbox: { show: true },
            tooltip: line_tooltip,
            height: "700px",
            dataZoom: data_zoom_slider,
            smoothMonotone: 'y'
        }
    end

    private

    def notable_events(driver)
        points = {
            label: {
                position: 'insideStartTop',
                show: true,
            },
            data: [
                { type: "max", label: { formatter: '{c}', fontSize: 11, color: '#C9B037' } },
                { type: "min", label: { formatter: '{c}', fontSize: 11, color: '#999' } },
            ],
            symbol: 'circle',
            symbolSize: 8,
        }
        (@podium_results_by_driver[driver.id] || []).each do |race_result|
            elo_val = race_result.send(@new_elo_col)
            next unless elo_val
            position = race_result.position_order
            style = {
                color: Race::PODIUM_COLORS[position],
                borderWidth: 1,
                borderColor: 'black'
            }
            style[:shadowBlur] = 3
            style[:shadowColor] = Race::PODIUM_COLORS[position] if position == 1
            points[:data] << podium_point(race_result, elo_val, position, style)
        end
        points
    end

end
