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
    assert entry.key?(:stock_portfolio_id)
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

  test "net equals total return (portfolio value minus starting capital)" do
    result = Fantasy::Leaderboard.new(season: seasons(:season_2026)).call

    result.each do |entry|
      assert_in_delta entry[:portfolio].total_return, entry[:net], 0.01
    end
  end

  test "uses the stock portfolio belonging to the same user and season" do
    result = Fantasy::Leaderboard.new(season: seasons(:season_2026)).call
    entry = result.find { |candidate| candidate[:portfolio] == fantasy_portfolios(:codex_2026) }

    assert_equal fantasy_stock_portfolios(:codex_stock_2026).id, entry[:stock_portfolio_id]
    assert_in_delta entry[:portfolio].portfolio_value, entry[:value], 0.01
  end
end
