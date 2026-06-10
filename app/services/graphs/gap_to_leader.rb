# Per-race "gap to leader" curves for the top-N drivers. Each line shows
# `leader.points − driver.points` after every completed round, so a flat or
# rising curve = leader pulling away, a falling curve = challenger closing in.
# Designed to live next to the cumulative-points chart on the Title Chase page.
class Graphs::GapToLeader
    include Graphs::Base

    TOP_N = 5

    def initialize(season:)
        @season = season
        @races = @season.races.joins(:driver_standings).distinct.order(:round).to_a
    end

    def data
        return {} if @races.empty?

        latest_race = @races.last
        top = DriverStanding.where(race: latest_race).order(:position).limit(TOP_N).to_a
        return {} if top.size < 2

        top_drivers = Driver.where(id: top.map(&:driver_id)).index_by(&:id)
        leader_id   = top.first.driver_id

        leader_pts_by_race = DriverStanding.where(race: @races, driver_id: leader_id)
                                            .pluck(:race_id, :points).to_h

        chaser_pts = DriverStanding.where(race: @races, driver_id: top.drop(1).map(&:driver_id))
                                    .pluck(:race_id, :driver_id, :points)
                                    .group_by { |_r, did, _p| did }
                                    .transform_values { |rows| rows.to_h { |r, _d, p| [r, p] } }

        constructor_by_driver = SeasonDriver.where(season: @season, driver_id: top_drivers.keys)
                                             .includes(:constructor)
                                             .group_by(&:driver_id)
                                             .transform_values { |sds| sds.last.constructor }

        series = top.drop(1).map do |row|
            driver = top_drivers[row.driver_id]
            label  = "#{driver.forename.first}. #{driver.surname}"
            constructor = constructor_by_driver[driver.id]
            color = constructor && Constructor::COLORS[constructor.constructor_ref.to_sym]

            {
                name:       label,
                type:       "line",
                smooth:     true,
                symbol:     "circle",
                symbolSize: 5,
                lineStyle:  { width: 1.5 },
                color:      color || driver.color,
                emphasis:   { focus: "series" },
                data:       @races.map do |r|
                    leader  = leader_pts_by_race[r.id]
                    chaser  = chaser_pts.dig(driver.id, r.id)
                    next nil if leader.nil? || chaser.nil?
                    leader - chaser
                end,
                connectNulls: true
            }
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
                name: "Pts behind leader",
                nameLocation: "middle",
                nameGap: 40,
                axisLabel: { color: "rgba(255,255,255,0.7)" },
                inverse: true   # 0 (caught up) on top, larger gap toward bottom
            },
            series: series,
            tooltip: line_tooltip.merge(trigger: "axis"),
            legend: { type: "plain", textStyle: { color: "rgba(255,255,255,0.85)" } },
            grid: { left: "60px", right: "120px", top: "40px", bottom: "60px", containLabel: false },
            dataZoom: data_zoom_slider,
            height: "360px"
        }
    end
end
