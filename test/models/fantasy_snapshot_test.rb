require "test_helper"

class FantasySnapshotTest < ActiveSupport::TestCase
  test "belongs to fantasy_portfolio" do
    snap = fantasy_snapshots(:codex_bahrain)
    assert_equal fantasy_portfolios(:codex_2026), snap.fantasy_portfolio
  end

  test "belongs to race" do
    snap = fantasy_snapshots(:codex_bahrain)
    assert_equal races(:bahrain_2026), snap.race
  end

  test "validates uniqueness of portfolio per race" do
    dup = FantasySnapshot.new(
      fantasy_portfolio: fantasy_portfolios(:codex_2026),
      race: races(:bahrain_2026),
      value: 9000.0,
      cash: 5000.0
    )
    refute dup.valid?
    assert_includes dup.errors[:fantasy_portfolio_id], "has already been taken"
  end

  test "validates value presence" do
    snap = FantasySnapshot.new(
      fantasy_portfolio: fantasy_portfolios(:codex_2026),
      race: races(:bahrain_2025),
      value: nil,
      cash: 1000.0
    )
    refute snap.valid?
    assert_includes snap.errors[:value], "can't be blank"
  end

  test "validates cash presence" do
    snap = FantasySnapshot.new(
      fantasy_portfolio: fantasy_portfolios(:codex_2026),
      race: races(:bahrain_2025),
      value: 9000.0,
      cash: nil
    )
    refute snap.valid?
    assert_includes snap.errors[:cash], "can't be blank"
  end

  test "stores value and cash correctly" do
    snap = fantasy_snapshots(:codex_bahrain)
    assert_in_delta 8500.0, snap.value, 0.01
    assert_in_delta 5000.0, snap.cash, 0.01
  end
end
