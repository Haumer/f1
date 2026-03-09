require "test_helper"

class FantasyTransactionTest < ActiveSupport::TestCase
  test "belongs to fantasy_portfolio" do
    tx = fantasy_transactions(:codex_buy_ver)
    assert_equal fantasy_portfolios(:codex_2026), tx.fantasy_portfolio
  end

  test "optionally belongs to driver" do
    tx = fantasy_transactions(:codex_buy_ver)
    assert_equal drivers(:verstappen), tx.driver

    team_tx = fantasy_transactions(:codex_team)
    assert_nil team_tx.driver
  end

  test "optionally belongs to race" do
    tx = fantasy_transactions(:codex_buy_ver)
    assert_equal races(:bahrain_2026), tx.race
  end

  test "validates kind inclusion" do
    tx = FantasyTransaction.new(fantasy_portfolio: fantasy_portfolios(:codex_2026), kind: "invalid", amount: 100)
    refute tx.valid?
    assert_includes tx.errors[:kind], "is not included in the list"
  end

  test "validates amount presence" do
    tx = FantasyTransaction.new(fantasy_portfolio: fantasy_portfolios(:codex_2026), kind: "buy", amount: nil)
    refute tx.valid?
    assert_includes tx.errors[:amount], "can't be blank"
  end

  test "KINDS constant has all valid kinds" do
    assert_equal %w[buy sell team_purchase bonus starting_capital], FantasyTransaction::KINDS
  end

  test "all valid kinds pass validation" do
    FantasyTransaction::KINDS.each do |kind|
      tx = FantasyTransaction.new(fantasy_portfolio: fantasy_portfolios(:codex_2026), kind: kind, amount: 100)
      assert tx.valid?, "Expected #{kind} to be valid"
    end
  end
end
