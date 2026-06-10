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

    test "matrix gives per-race scoring rate alive challengers need under each leader scenario" do
      result = TitleChase.new(season: @season).call

      nor_row = result[:matrix].find { |m| m.driver == drivers(:norris) }
      # remaining_main = 1, leader = 25, NOR = 18
      # leader_max = 25 + 25 = 50,  need = (50 - 18) / 1 = 32
      # leader_zero_end = 25,        need = (25 - 18) / 1 = 7
      # leader avg pace = 25/1=25, leader_avg_end = 25 + 25 = 50, need = 32
      assert_equal 32.0, nor_row.need_if_leader_max
      assert_equal 32.0, nor_row.need_if_leader_avg
      assert_equal 7.0,  nor_row.need_if_leader_zero
    end
  end
end
