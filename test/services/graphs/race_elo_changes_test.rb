require "test_helper"

class Graphs::RaceEloChangesTest < ActiveSupport::TestCase
  test "missing Elo snapshots are omitted rather than charted as zero" do
    race_results(:bahrain_2026_norris).update!(old_elo_v2: nil)
    data = Graphs::RaceEloChanges.new(race: races(:bahrain_2026)).data
    assert_equal 3, data[:series].first[:data].size
    assert_not_includes data[:yAxis][:data], "L.Norris"
  end
end
