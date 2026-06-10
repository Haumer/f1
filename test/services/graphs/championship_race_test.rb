require "test_helper"

class Graphs::ChampionshipRaceTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:season_2026)  # bahrain only has standings; melbourne has none
  end

  test "returns empty hash when season has no races" do
    empty = Season.create!(year: "2099")
    assert_equal({}, Graphs::ChampionshipRace.new(season: empty).data)
  end

  test "builds top-N line series and marks the clinch round on the champion's series" do
    data = Graphs::ChampionshipRace.new(season: @season, clinch_round: 1).data

    assert_equal "category", data[:xAxis][:type]
    assert_equal %w[R1 R2], data[:xAxis][:data]

    series = data[:series]
    assert series.any?, "has series"
    series.each { |s| assert_equal "line", s[:type] }

    champion = series.first
    assert_equal "M. Verstappen", champion[:name]
    assert champion[:markLine].present?, "champion gets the clinch markLine"
    assert(series[1..].all? { |s| s[:markLine].nil? }, "other series have no markLine")
    assert_equal 3, champion[:lineStyle][:width], "champion line is highlighted"
  end

  test "no markLine when no clinch_round provided (live seasons)" do
    data = Graphs::ChampionshipRace.new(season: @season, clinch_round: nil).data
    assert data[:series].none? { |s| s[:markLine].present? }
  end
end
