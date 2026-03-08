require "test_helper"

class Fantasy::LeaderboardTest < ActiveSupport::TestCase
  test "returns array of portfolio entries" do
    result = Fantasy::Leaderboard.new(season: seasons(:season_2026)).call
    assert_kind_of Array, result
    assert result.any?
  end

  test "entries have portfolio, value, and net keys" do
    result = Fantasy::Leaderboard.new(season: seasons(:season_2026)).call
    entry = result.first
    assert entry.key?(:portfolio)
    assert entry.key?(:value)
    assert entry.key?(:net)
  end

  test "sorted by net profit descending" do
    result = Fantasy::Leaderboard.new(season: seasons(:season_2026)).call
    nets = result.map { |e| e[:net] }
    assert_equal nets.sort.reverse, nets
  end

  test "returns empty array for season with no portfolios" do
    result = Fantasy::Leaderboard.new(season: seasons(:season_2025)).call
    assert_equal [], result
  end

  test "net equals portfolio value minus starting capital" do
    result = Fantasy::Leaderboard.new(season: seasons(:season_2026)).call
    entry = result.first
    expected_net = entry[:portfolio].profit_loss
    assert_in_delta expected_net, entry[:net], 0.01
  end
end
