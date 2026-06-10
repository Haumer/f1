require "test_helper"

class Graphs::GapToLeaderTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:season_2026)
  end

  test "returns empty when fewer than 2 drivers have standings" do
    empty = Season.create!(year: "2099")
    assert_equal({}, Graphs::GapToLeader.new(season: empty).data)
  end

  test "builds chaser series with leader.points - driver.points" do
    data = Graphs::GapToLeader.new(season: @season).data

    # Fixtures: bahrain VER 25, NOR 18, LEC 15, PIA 12. Leader is VER.
    # 4 top drivers -> 3 chasers (NOR, LEC, PIA).
    assert_equal 3, data[:series].size
    nor_series = data[:series].find { |s| s[:name] == "L. Norris" }
    assert_equal [7], nor_series[:data]  # 25 - 18
  end

  test "yAxis is inverted so smaller gaps appear higher" do
    data = Graphs::GapToLeader.new(season: @season).data
    assert_equal true, data[:yAxis][:inverse]
  end
end
