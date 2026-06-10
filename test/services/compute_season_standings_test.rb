require "test_helper"

class ComputeSeasonStandingsTest < ActiveSupport::TestCase
  setup do
    @bahrain = races(:bahrain_2026)        # 4 race_results already in fixtures
    @melbourne = races(:melbourne_2026)
  end

  test "writes one DriverStanding per driver with results in the race" do
    DriverStanding.where(race: @bahrain).delete_all
    assert_difference -> { DriverStanding.where(race: @bahrain).count }, 4 do
      ComputeSeasonStandings.new(race: @bahrain).call
    end
  end

  test "positions reflect cumulative points order: VER 25 > NOR 18 > LEC 15 > PIA 12" do
    ComputeSeasonStandings.new(race: @bahrain).call

    by_pos = DriverStanding.where(race: @bahrain).index_by(&:position)
    assert_equal drivers(:verstappen).id, by_pos[1].driver_id
    assert_equal 25.0, by_pos[1].points
    assert_equal drivers(:norris).id,     by_pos[2].driver_id
    assert_equal 18.0, by_pos[2].points
    assert_equal drivers(:leclerc).id,    by_pos[3].driver_id
    assert_equal drivers(:piastri).id,    by_pos[4].driver_id
  end

  test "P1 finishers get a win counted" do
    ComputeSeasonStandings.new(race: @bahrain).call
    ver_ds = DriverStanding.find_by!(race: @bahrain, driver: drivers(:verstappen))
    assert_equal 1, ver_ds.wins
    nor_ds = DriverStanding.find_by!(race: @bahrain, driver: drivers(:norris))
    assert_equal 0, nor_ds.wins
  end

  test "returns the number of standings written" do
    assert_equal 4, ComputeSeasonStandings.new(race: @bahrain).call
  end

  test "is idempotent: running twice keeps positions stable" do
    ComputeSeasonStandings.new(race: @bahrain).call
    first = DriverStanding.where(race: @bahrain).order(:position).pluck(:driver_id, :points)
    ComputeSeasonStandings.new(race: @bahrain).call
    second = DriverStanding.where(race: @bahrain).order(:position).pluck(:driver_id, :points)
    assert_equal first, second
  end

  test "countback breaks ties on most P1s" do
    # Tie VER and NOR on points by zeroing both rows then giving NOR a higher
    # `points` than VER but VER one P1 — VER should still win on countback.
    rr_ver = race_results(:bahrain_2026_verstappen)
    rr_nor = race_results(:bahrain_2026_norris)
    rr_ver.update!(points: 20, position_order: 1)
    rr_nor.update!(points: 20, position_order: 2)

    ComputeSeasonStandings.new(race: @bahrain).call
    by_pos = DriverStanding.where(race: @bahrain).index_by(&:position)
    assert_equal drivers(:verstappen).id, by_pos[1].driver_id, "VER's P1 should outrank NOR's P2 on countback"
    assert_equal drivers(:norris).id,     by_pos[2].driver_id
  end
end
