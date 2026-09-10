require "test_helper"

class Homepage::LeaderboardPreviewTest < ActiveSupport::TestCase
  test "returns ranked entries with the latest stock activity" do
    fantasy_portfolios(:codex_2026).update!(cash: 10_000)
    latest = fantasy_stock_portfolios(:codex_stock_2026).transactions.create!(
      driver: drivers(:leclerc),
      kind: "buy",
      amount: -100,
      created_at: 1.minute.from_now
    )

    result = Homepage::LeaderboardPreview.new(season: seasons(:season_2026)).call

    assert_equal [1, 2], result.entries.map { |entry| entry[:rank] }
    assert_equal users(:codex), result.entries.first[:user]
    assert_equal latest, result.entries.first[:last_action]
    assert_equal 100, result.entries.first[:gap_percent]
    assert_equal result.entries.first[:net], result.max_net
    assert_nil result.self_entry
  end

  test "pins the current user below the preview limit" do
    result = Homepage::LeaderboardPreview.new(
      season: seasons(:season_2026),
      user: users(:latejoin),
      limit: 1
    ).call

    assert_equal [users(:codex)], result.entries.map { |entry| entry[:user] }
    assert_equal users(:latejoin), result.self_entry[:user]
    assert_equal 2, result.self_entry[:rank]
    assert_nil result.self_entry[:last_action]
  end

  test "returns an empty result when the season has no portfolios" do
    result = Homepage::LeaderboardPreview.new(season: seasons(:season_2025)).call

    assert_empty result.entries
    assert_nil result.self_entry
    assert_equal 0, result.max_net
  end
end
