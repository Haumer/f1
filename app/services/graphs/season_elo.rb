class Graphs::SeasonElo
    def initialize(season:, top_n: nil)
        @season = season
        @races = @season.races.sorted.includes(:circuit)
        if top_n
            elo_col = Setting.elo_column(:elo)
            driver_ids = @season.drivers.distinct.pluck(:id)
            @drivers = Driver.where(id: driver_ids).where.not(elo_col => nil).order(elo_col => :desc).limit(top_n)
        else
            @drivers = @season.drivers.distinct
        end
        @race_results_lookup = RaceResult.where(race: @races, driver: @drivers)
                                         .group_by { |rr| [rr.race_id, rr.driver_id] }
        @constructor_by_driver = SeasonDriver.where(season: @season, driver: @drivers)
                                             .includes(:constructor)
                                             .order(:id)
                                             .group_by(&:driver_id)
                                             .transform_values { |sds| sds.last.constructor }
    end

    def season_elo_data
        new_elo_col = Setting.elo_column(:new_elo).to_sym
        @series_data = @drivers.map do |driver|
            driver_name = "#{driver.forename.first}.#{driver.surname}"
            constructor = @constructor_by_driver[driver.id]
            team_color = constructor && Constructor::COLORS[constructor.constructor_ref.to_sym]
            {
                data: @races.map do |race|
                    race_result = @race_results_lookup[[race.id, driver.id]]&.first
                    elo_val = race_result&.send(new_elo_col)
                    if elo_val
                        { name: driver_name, value: elo_val.round }
                    else
                        '-'
                    end
                end,
                type: 'line',
                name: driver_name,
                color: team_color || driver.color,
                emphasis: { focus: 'series' },
                endLabel: {
                    show: true,
                    formatter: '{a}',
                    distance: 20
                },
                smooth: true,
                connectNulls: false,
                symbolSize: 8,
            }
        end

        elo_values = @race_results_lookup.values.flatten.filter_map { |rr| rr.send(new_elo_col)&.round }
        min_elo = elo_values.min || 800
        max_elo = elo_values.max || 2000

        {
            label: {
                show: false,
                position: "right"
            },
            xAxis: {
                type: 'category',
                data: @races.map { |race| "#{race.circuit.circuit_ref} #{race.date.strftime("%b %d, %Y")}" }
            },
            yAxis: {
                type: 'value',
                min: (min_elo - 50),
                max: (max_elo + 50),
            },
            series: @series_data,
            dataZoom: [
                {
                    id: 'dataZoomX',
                    type: 'slider',
                    xAxisIndex: [0],
                    filterMode: 'filter'
                }
            ],
            height: "400px",
            legend: {
                type: 'plain',
                itemGap: 2,
            },
        }
    end
end
