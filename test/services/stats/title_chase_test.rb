require "test_helper"

module Stats
  class TitleChaseTest < ActiveSupport::TestCase
    setup do
      @season = seasons(:season_2026)
      # bahrain_2026 driver_standings fixtures: VER 25, NOR 18, LEC 15, PIA 12.
      # Two races in 2026 fixtures (bahrain, melbourne); only bahrain has standings.
      # With one race done and one to go, race_win = 25 (2025+ rule), sprint_win = 0
      # (no PointsSystem fixture). Max extra = 25.
    end

    test "returns blank-ish result with a message when no standings exist yet" do
      Season.create!(year: "2099")
      blank_season = Season.find_by(year: "2099")

      result = TitleChase.new(season: blank_season).call

      assert_nil result[:leader]
      assert_equal [], result[:rows]
      assert_match(/No race results/, result[:message])
    end

    test "marks the leader and flags alive vs eliminated using max-possible" do
      result = TitleChase.new(season: @season).call

      assert_equal drivers(:verstappen), result[:leader]
      assert_equal 25, result[:leader_points]
      assert_equal 1, result[:remaining_races]

      ver = result[:rows].find { |r| r.driver == drivers(:verstappen) }
      nor = result[:rows].find { |r| r.driver == drivers(:norris) }
      pia = result[:rows].find { |r| r.driver == drivers(:piastri) }

      assert_equal :leader,     ver.status
      assert_equal :alive,      nor.status # 18 + 25 = 43 >= leader 25
      assert_equal :alive,      pia.status # 12 + 25 = 37 >= leader 25
      assert_equal 43,          nor.max_possible # 18 + 25 = 43
      assert_equal 7,           nor.behind
    end

    test "magic number is the points the leader still needs to gain over the best chaser" do
      result = TitleChase.new(season: @season).call

      # Best chaser is NOR at 18; max extra = 25. NOR's max = 43. Leader = 25.
      # Magic = (43 - 25) + 1 = 19
      assert_equal 19, result[:magic_number]
      refute result[:clinched]
    end

    test "leader is clinched when magic number is zero" do
      # Make bahrain the only race in the season -> remaining = 0 -> max_extra = 0 ->
      # NOR's max = 18 < leader 25 -> clinched.
      races(:melbourne_2026).update!(cancelled: true)

      result = TitleChase.new(season: @season).call

      assert_equal 0, result[:magic_number]
      assert result[:clinched]
      assert_equal races(:bahrain_2026), result[:clinch][:race]
      assert_equal 1,  result[:clinch][:round]
      assert_equal 7,  result[:clinch][:margin]
      assert_equal drivers(:norris), result[:clinch][:runner_up]
    end

    test "eliminated rows surface when leader has clinched" do
      races(:melbourne_2026).update!(cancelled: true)
      result = TitleChase.new(season: @season).call

      nor = result[:rows].find { |r| r.driver == drivers(:norris) }
      assert_equal :eliminated, nor.status # 18 + 0 = 18 < leader 25
      refute nor.alive
    end

    test "chaser whose max ONLY equals leader's current is eliminated (strict overtake)" do
      # Set NOR exactly at 0, remaining race max = 25 -> NOR.max = 25 = VER.current.
      # Without tiebreakers a tie isn't an overtake, so this should be :eliminated.
      DriverStanding.find_by(race_id: races(:bahrain_2026).id, driver_id: drivers(:norris).id)
                    .update!(points: 0)

      result = TitleChase.new(season: @season).call

      nor = result[:rows].find { |r| r.driver == drivers(:norris) }
      assert_equal :eliminated, nor.status
    end

    test "splits live challengers by whether they need the leader to drop off" do
      # Fixture: 1 round done, 1 to go. VER 25, NOR 18, PIA 12, max extra 25.
      # Leader is scoring 25/round, so projected final = 50.
      #   NOR ceiling 43 -> below 50, can only win if VER scores under his rate.
      # Push LEC above the projection to prove the other branch fires.
      DriverStanding.find_by(race_id: races(:bahrain_2026).id, driver_id: drivers(:leclerc).id)
                    .update!(points: 26)

      result = TitleChase.new(season: @season).call
      by = result[:rows].to_h { |r| [r.driver, r.status] }

      assert_equal :contention, by[drivers(:leclerc)],
        "ceiling 26+25=51 clears the leader's projected 50 — a threat on current form"
      assert_equal :alive, by[drivers(:norris)],
        "ceiling 43 falls short of the projected 50 — only wins if the leader slips"
      assert_equal :leader, by[drivers(:verstappen)]
    end

    test "matrix covers both live states, not just the ones needing a slip" do
      # Regression: :contention was split out of :alive, and build_matrix kept
      # filtering on :alive alone — which dropped the actual contenders from
      # the table built for them.
      DriverStanding.find_by(race_id: races(:bahrain_2026).id, driver_id: drivers(:leclerc).id)
                    .update!(points: 26)

      result = TitleChase.new(season: @season).call
      drivers_in_matrix = result[:matrix].map(&:driver)

      assert_includes drivers_in_matrix, drivers(:leclerc), "in-contention driver must appear"
      assert_includes drivers_in_matrix, drivers(:norris),  "needs-a-slip driver must appear"
      assert_not_includes drivers_in_matrix, drivers(:verstappen), "the leader is not a challenger"
    end

    test "matrix translates the gap into the worst finish the leader can afford" do
      # A real ladder, so the position lookup has something to walk. Created here
      # rather than as a fixture because the other tests in this file rely on
      # there being no PointsSystem (race_win falls back to 25, sprint_win to 0).
      PointsSystem.create!(
        season: @season,
        race_points: { "1" => 25, "2" => 18, "3" => 15, "4" => 12, "5" => 10 },
        sprint_points: {},
        fastest_lap_point: 0
      )

      result = TitleChase.new(season: @season).call
      nor_row = result[:matrix].find { |m| m.driver == drivers(:norris) }

      # 1 race left, no sprints. NOR 18, VER 25.
      # Wins out            -> 18 + 25            = 43
      # Leader's ceiling    -> 43 - 25 - 1        = 17  (strict: a tie is no overtake)
      # P1 pays 25 > 17, P2 pays 18 > 17, P3 pays 15 <= 17 -> leader must be P3 or worse
      assert_equal 43,  nor_row.best_case
      assert_equal 17,  nor_row.leader_cap
      assert_equal 3,   nor_row.leader_max_position
      # Must out-score the leader by the gap plus one, spread over the rounds left.
      assert_equal 8.0, nor_row.swing_per_round
    end

    test "matrix counts sprint points against the leader's allowance" do
      # Same ladder, but now the remaining round carries a sprint. The leader
      # picks up sprint points too, so their allowance is tighter and the
      # position they must fall to is correspondingly lower.
      PointsSystem.create!(
        season: @season,
        race_points: { "1" => 25, "2" => 18, "3" => 15, "4" => 12, "5" => 10 },
        sprint_points: { "1" => 8, "2" => 7, "3" => 6 },
        fastest_lap_point: 0
      )
      races(:melbourne_2026).update!(sprint_time: "18:00:00") # sprint? is derived from sprint_time

      result = TitleChase.new(season: @season).call
      nor_row = result[:matrix].find { |m| m.driver == drivers(:norris) }

      # Wins out now takes the sprint too -> 18 + 25 + 8 = 51
      # Leader's ceiling -> 51 - 25 - 1 = 25
      # P1: 25 + 8 = 33 > 25.  P2: 18 + 7 = 25 <= 25 -> P2 or worse.
      assert_equal 51, nor_row.best_case
      assert_equal 25, nor_row.leader_cap
      assert_equal 2,  nor_row.leader_max_position
    end

    test "matrix degrades gracefully when the season has no points ladder" do
      # No PointsSystem: race_win falls back to 25 and the ladder collapses to
      # winner-takes-all, so there is no lesser position to name.
      result = TitleChase.new(season: @season).call
      nor_row = result[:matrix].find { |m| m.driver == drivers(:norris) }

      assert_equal 43, nor_row.best_case
      assert_nil nor_row.leader_max_position, "winner-takes-all ladder has no P2+ to fall to"
    end

  end
end
