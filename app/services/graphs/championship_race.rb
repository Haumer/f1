# Cumulative-points line chart for a season's title race. One line per
# top-N driver (final standings), colored by constructor; champion's line
# is thicker and highlighted. A dashed vertical line marks the round at
# which the title was mathematically clinched.
class Graphs::ChampionshipRace
    include Graphs::Base

    TOP_N = 5

    def initialize(season:, clinch_round: nil)
        @season = season
        @clinch_round = clinch_round
        @races = @season.races.sorted.includes(:circuit).to_a
    end

    def data
        return {} if @races.empty?

        # Use the latest race that actually HAS standings — not the calendar's
        # final race, which may be in the future or unsynced.
        latest_race = @season.races.joins(:driver_standings).order(round: :desc).distinct.first
        return {} if latest_race.nil?

        final_standings = DriverStanding.where(race: latest_race).order(:position).limit(TOP_N).to_a
        return {} if final_standings.empty?

        top_drivers = Driver.where(id: final_standings.map(&:driver_id)).index_by(&:id)
        champion_id = final_standings.first.driver_id

        # Per-(race, driver) cumulative points — single query.
        standings = DriverStanding.where(race: @races, driver_id: top_drivers.keys)
                                  .pluck(:race_id, :driver_id, :points)
                                  .group_by { |_r, did, _p| did }
                                  .transform_values { |rows| rows.to_h { |r, _d, p| [r, p] } }

        constructor_by_driver = SeasonDriver.where(season: @season, driver_id: top_drivers.keys)
                                            .includes(:constructor)
                                            .group_by(&:driver_id)
                                            .transform_values { |sds| sds.last.constructor }

        series = final_standings.map do |s|
            driver = top_drivers[s.driver_id]
            label  = "#{driver.forename.first}. #{driver.surname}"
            constructor = constructor_by_driver[driver.id]
            color = constructor && Constructor::COLORS[constructor.constructor_ref.to_sym]
            is_champion = driver.id == champion_id

            line = {
                name:        label,
                type:        "line",
                smooth:      true,
                symbol:      "circle",
                symbolSize:  is_champion ? 8 : 5,
                lineStyle:   { width: is_champion ? 3 : 1.5 },
                color:       color || driver.color,
                emphasis:    { focus: "series" },
                # "" — not 0 — for rounds with no standings yet. @races is the
                # whole calendar, so mid-season every future round would
                # otherwise plot a literal zero and drop this cumulative line
                # off a cliff to the axis. echarts renders "" as a gap.
                data:        @races.map { |r| standings.dig(driver.id, r.id) || "" },
                z:           is_champion ? 5 : 2,
            }

            # Attach clinch marker to the champion's series only — keeps it visible
            # and contextually anchored to whose path is being shown.
            if is_champion && @clinch_round
                line[:markLine] = clinch_mark_line
            end

            line
        end

        {
            backgroundColor: "transparent",
            xAxis: {
                type: "category",
                data: @races.map { |r| "R#{r.round}" },
                axisLabel: { fontSize: 10, color: "rgba(255,255,255,0.7)" }
            },
            yAxis: {
                type: "value",
                name: "Points",
                nameLocation: "middle",
                nameGap: 40,
                axisLabel: { color: "rgba(255,255,255,0.7)" }
            },
            series: series,
            tooltip: line_tooltip.merge(trigger: "axis"),
            legend: { type: "plain", textStyle: { color: "rgba(255,255,255,0.85)" } },
            grid: { left: "60px", right: "120px", top: "40px", bottom: "60px", containLabel: false },
            dataZoom: data_zoom_slider,
            height: "420px"
        }
    end

    private

    def clinch_mark_line
        {
            symbol: "none",
            label: {
                formatter: "Clinched · R#{@clinch_round}",
                position: "insideEndTop",
                color: "#f0c850",
                fontSize: 11
            },
            lineStyle: { color: "#f0c850", type: "dashed", width: 2 },
            data: [[
                { xAxis: "R#{@clinch_round}", yAxis: 0 },
                { xAxis: "R#{@clinch_round}", yAxis: 9999 }
            ]]
        }
    end
end
