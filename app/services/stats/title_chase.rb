# Computes title-race state for a season: leader, "magic number" to clinch,
# alive/eliminated drivers, max possible points per driver, and a small
# per-driver pace matrix showing what each alive challenger would need to score
# under three leader scenarios (zero, current pace, max).
#
# For past seasons we detect the round at which the champion mathematically
# clinched and the margin they had at that moment.
module Stats
    class TitleChase
        FALLBACK_RACE_WIN   = 25
        FALLBACK_SPRINT_WIN = 0

        Row = Struct.new(:driver, :position, :current, :max_possible, :behind, :alive, :status, keyword_init: true)
        MatrixRow = Struct.new(:driver, :best_case, :leader_cap, :leader_max_position, :swing_per_round, keyword_init: true)

        def initialize(season:)
            @season = season
        end

        def call
            return blank if @season.nil?

            @points = PointsSystem.find_by(season: @season)
            # Race max counts the win + fastest-lap point if the season awards one
            # (e.g. 2019-2024 = 26, 2025+ = 25). Conservative upper bound for chasers.
            base_race = @points&.race_points&.values&.max || FALLBACK_RACE_WIN
            @race_win = base_race + (@points&.fastest_lap_point || 0)
            @sprint_win = @points&.sprint_points&.values&.max || FALLBACK_SPRINT_WIN

            standings = latest_standings
            return blank.merge(message: "No race results yet for #{@season.year}.") if standings.empty?

            remaining_main, remaining_sprint = remaining_counts
            max_extra = remaining_main * @race_win + remaining_sprint * @sprint_win

            leader = standings.first
            rows = standings.map do |s|
                # Strict ">" — a chaser whose max EQUALS the leader's current can
                # only tie, never overtake on points alone. Without tiebreakers in
                # v1 we treat that as eliminated.
                status =
                    if s.driver_id == leader.driver_id
                        :leader
                    elsif (s.points + max_extra) > leader.points
                        :alive
                    else
                        :eliminated
                    end
                Row.new(
                    driver:       s.driver,
                    position:     s.position,
                    current:      s.points.to_i,
                    max_possible: (s.points + max_extra).to_i,
                    behind:       (leader.points - s.points).to_i,
                    alive:        status != :eliminated,
                    status:       status
                )
            end

            # Magic number = net points the leader must gain over the best chaser
            # to make the chaser's max-possible strictly less than the leader's
            # current. Net = leader gains + chaser missed-max, combined.
            best_chaser = standings[1..]&.max_by(&:points)
            magic =
                if best_chaser.nil?
                    0
                else
                    [(best_chaser.points + max_extra) - leader.points + 1, 0].max.to_i
                end
            clinched = magic.zero? && best_chaser.present?

            clinch = clinched ? clinch_summary : nil

            {
                season:           @season,
                leader:           leader.driver,
                leader_points:    leader.points.to_i,
                magic_number:     magic,
                clinched:         clinched,
                clinch:           clinch,
                remaining_races:  remaining_main,
                remaining_sprints: remaining_sprint,
                race_win:         @race_win,
                sprint_win:       @sprint_win,
                rows:             rows,
                matrix:           build_matrix(rows, leader, remaining_main, remaining_sprint),
                message:          nil
            }
        end

        private

        def blank
            { season: @season, leader: nil, rows: [], matrix: [],
              magic_number: nil, clinched: false, clinch: nil,
              remaining_races: nil, remaining_sprints: nil, message: nil }
        end

        # Latest race in the season that has DriverStandings recorded.
        def latest_standings
            last_race = @season.races
                               .joins(:driver_standings)
                               .order(round: :desc)
                               .distinct
                               .first
            return [] unless last_race
            DriverStanding.where(race: last_race).includes(:driver).order(:position).to_a
        end

        # Counts a race as "done" when it has DriverStandings rows attached.
        def remaining_counts
            all = @season.races.to_a
            done_ids = @season.races.joins(:driver_standings).distinct.pluck(:id)
            remaining = all.reject { |r| done_ids.include?(r.id) }
            remaining_main = remaining.size
            remaining_sprint = remaining.count(&:sprint?)
            [remaining_main, remaining_sprint]
        end

        # Walk race-by-race in chronological order; first round where the leader's
        # current points >= max(other_driver.points + max_remaining_after_this_round).
        def clinch_summary
            races_in_order = @season.races.joins(:driver_standings).distinct.order(:round).to_a
            total_main = @season.races.count
            total_sprint = @season.races.count(&:sprint?)

            done_main = 0
            done_sprint = 0
            races_in_order.each do |race|
                done_main += 1
                done_sprint += 1 if race.sprint?
                remaining_main = total_main - done_main
                remaining_sprint = total_sprint - done_sprint
                max_extra = remaining_main * @race_win + remaining_sprint * @sprint_win

                ds = DriverStanding.where(race: race).order(:position).to_a
                next if ds.size < 2
                leader_row = ds.first
                best_chaser = ds[1..].max_by(&:points)
                # Strict ">" matches the live magic-number formula.
                if leader_row.points > (best_chaser.points + max_extra)
                    return {
                        race:           race,
                        round:          race.round,
                        races_left:     remaining_main,
                        sprints_left:   remaining_sprint,
                        margin:         (leader_row.points - best_chaser.points).to_i,
                        runner_up:      best_chaser.driver
                    }
                end
            end
            nil
        end

        # For each alive challenger: their best possible finish (win every remaining
        # race and sprint), and — given that — the worst the leader is allowed to
        # finish, expressed as a position on the actual points ladder.
        #
        # This replaces a three-column "average points per race" matrix. That was
        # unusable for two reasons. Its headline column ("if the leader maxes")
        # is impossible by construction — if the leader wins out, nobody behind
        # can catch them, so every cell in it was a target no one could ever hit.
        # And the remaining cells were decimals like 24.5, while the ladder only
        # pays 25/18/15/12/10/8/6/4/2/1. There is no finish worth 24.5, so the
        # number couldn't be turned into anything a reader could picture.
        def build_matrix(rows, leader_standing, remaining_main, remaining_sprint)
            return [] if remaining_main.zero?

            race_ladder   = points_ladder(@points&.race_points, @race_win)
            sprint_ladder = points_ladder(@points&.sprint_points, @sprint_win)
            leader_current = leader_standing.points.to_i

            rows.select { |r| r.status == :alive }.map do |r|
                # Ceiling for this challenger: P1 in every remaining race AND sprint.
                best_case = r.current + remaining_main * @race_win + remaining_sprint * @sprint_win

                # Most the leader can still score and lose. Strict — matching the
                # magic-number convention above, a tie is not an overtake.
                cap = best_case - leader_current - 1

                # Walk the ladder for the best finish the leader could repeat every
                # round and still fall short. Sprints count: if the challenger is
                # winning everything the leader is picking up sprint points too, and
                # ignoring them would flatter the challenger.
                position = race_ladder.keys.sort.find do |pos|
                    (race_ladder[pos] * remaining_main) + (sprint_ladder.fetch(pos, 0) * remaining_sprint) <= cap
                end

                MatrixRow.new(
                    driver:              r.driver,
                    best_case:           best_case,
                    leader_cap:          cap,
                    leader_max_position: position,
                    # Average margin per round the challenger must take out of the
                    # leader — "finish this far ahead, every round".
                    swing_per_round:     ((r.behind + 1) / remaining_main.to_f).round(1)
                )
            end
        end

        # Position => points, integer-keyed. PointsSystem stores string keys; a
        # season with no configured ladder falls back to a winner-takes-all shape
        # so the caller still gets a usable (if crude) answer rather than nil.
        def points_ladder(raw, winner_value)
            return { 1 => winner_value } if raw.blank?
            raw.to_h { |pos, val| [pos.to_i, val.to_i] }
        end
    end
end
