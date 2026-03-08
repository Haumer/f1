require "test_helper"

class FantasyStockTransactionTest < ActiveSupport::TestCase
  test "belongs to fantasy_stock_portfolio" do
    tx = fantasy_stock_transactions(:codex_stock_buy_ver)
    assert_equal fantasy_stock_portfolios(:codex_stock_2026), tx.fantasy_stock_portfolio
  end

  test "optionally belongs to driver" do
    tx = fantasy_stock_transactions(:codex_stock_buy_ver)
    assert_equal drivers(:verstappen), tx.driver
  end

  test "optionally belongs to race" do
    tx = fantasy_stock_transactions(:codex_stock_buy_ver)
    assert_equal races(:bahrain_2026), tx.race
  end

  test "validates kind presence" do
    tx = FantasyStockTransaction.new(
      fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026),
      kind: nil,
      amount: 100
    )
    refute tx.valid?
    assert_includes tx.errors[:kind], "can't be blank"
  end

  test "validates amount presence" do
    tx = FantasyStockTransaction.new(
      fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026),
      kind: "buy_long",
      amount: nil
    )
    refute tx.valid?
    assert_includes tx.errors[:amount], "can't be blank"
  end
end
