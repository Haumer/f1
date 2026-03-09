require "test_helper"

class Fantasy::ReplayTransactionsTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:season_2025)
    @user = users(:codex)

    # Create portfolio manually (not via service, to simulate missing starting_capital txn)
    @portfolio = FantasyPortfolio.create!(
      user: @user, season: @season,
      cash: 999, # intentionally wrong
      starting_capital: 5000
    )
  end

  test "backfills roster starting_capital transaction" do
    assert_equal 0, @portfolio.transactions.where(kind: "starting_capital").count

    results = Fantasy::ReplayTransactions.new(season: @season, dry_run: true).call
    entry = results.find { |r| r[:user] == @user.username }

    # Should have backfilled the starting_capital transaction
    assert_equal 1, @portfolio.transactions.where(kind: "starting_capital").count
    assert_equal 5000, entry[:new_cash]
  end

  test "backfills stock starting_capital transaction" do
    sp = FantasyStockPortfolio.create!(
      user: @user, season: @season, cash: 0, starting_capital: 3000
    )

    results = Fantasy::ReplayTransactions.new(season: @season, dry_run: true).call
    entry = results.find { |r| r[:user] == @user.username }

    stock_cap_txns = @portfolio.transactions.where(kind: "starting_capital", note: "Stock market unlocked")
    assert_equal 1, stock_cap_txns.count
    assert_equal 3000, stock_cap_txns.first.amount
    assert_equal 8000, entry[:new_cash] # 5000 + 3000
  end

  test "replays roster buy transactions correctly" do
    @portfolio.transactions.create!(kind: "starting_capital", amount: 5000, note: "Roster starting capital")
    @portfolio.transactions.create!(kind: "buy", amount: -2000, note: "Bought driver A")
    @portfolio.transactions.create!(kind: "buy", amount: -1500, note: "Bought driver B")

    results = Fantasy::ReplayTransactions.new(season: @season, dry_run: true).call
    entry = results.find { |r| r[:user] == @user.username }

    assert_equal 1500, entry[:new_cash] # 5000 - 2000 - 1500
    assert_equal 999, entry[:old_cash]  # unchanged (dry run)
  end

  test "replays mixed roster and stock transactions in timestamp order" do
    sp = FantasyStockPortfolio.create!(
      user: @user, season: @season, cash: 0, starting_capital: 3000
    )

    # Simulate: starting capital → buy driver → stock capital → buy stock → dividend
    @portfolio.transactions.create!(kind: "starting_capital", amount: 5000, note: "Roster starting capital", created_at: 1.hour.ago)
    @portfolio.transactions.create!(kind: "buy", amount: -2000, note: "Bought driver", created_at: 50.minutes.ago)
    @portfolio.transactions.create!(kind: "starting_capital", amount: 3000, note: "Stock market unlocked", created_at: 40.minutes.ago)
    sp.transactions.create!(kind: "buy", amount: -500, note: "Bought stock", created_at: 30.minutes.ago)
    sp.transactions.create!(kind: "dividend", amount: 10, note: "Dividend", created_at: 20.minutes.ago)
    sp.transactions.create!(kind: "borrow_fee", amount: -5, note: "Fee", created_at: 10.minutes.ago)

    results = Fantasy::ReplayTransactions.new(season: @season, dry_run: true).call
    entry = results.find { |r| r[:user] == @user.username }

    # 5000 - 2000 + 3000 - 500 + 10 - 5 = 5505
    assert_equal 5505, entry[:new_cash]
  end

  test "dry run does not modify cash" do
    @portfolio.transactions.create!(kind: "starting_capital", amount: 5000, note: "Roster starting capital")

    Fantasy::ReplayTransactions.new(season: @season, dry_run: true).call
    @portfolio.reload
    assert_equal 999, @portfolio.cash # unchanged
  end

  test "live run updates cash" do
    @portfolio.transactions.create!(kind: "starting_capital", amount: 5000, note: "Roster starting capital")
    @portfolio.transactions.create!(kind: "buy", amount: -2000, note: "Bought driver")

    Fantasy::ReplayTransactions.new(season: @season, dry_run: false).call
    @portfolio.reload
    assert_in_delta 3000, @portfolio.cash, 0.01
  end

  test "does not duplicate starting_capital transactions on repeated runs" do
    Fantasy::ReplayTransactions.new(season: @season, dry_run: false).call
    Fantasy::ReplayTransactions.new(season: @season, dry_run: false).call

    assert_equal 1, @portfolio.transactions.where(kind: "starting_capital").count
  end

  test "does not duplicate stock starting_capital on repeated runs" do
    sp = FantasyStockPortfolio.create!(
      user: @user, season: @season, cash: 0, starting_capital: 3000
    )

    Fantasy::ReplayTransactions.new(season: @season, dry_run: false).call
    Fantasy::ReplayTransactions.new(season: @season, dry_run: false).call

    stock_cap_count = @portfolio.transactions.where(kind: "starting_capital", note: "Stock market unlocked").count
    assert_equal 1, stock_cap_count
  end

  test "user with no transactions gets starting capital as cash" do
    results = Fantasy::ReplayTransactions.new(season: @season, dry_run: false).call
    @portfolio.reload

    assert_in_delta 5000, @portfolio.cash, 0.01
  end

  test "sell transaction adds cash back" do
    @portfolio.transactions.create!(kind: "starting_capital", amount: 5000, note: "Roster starting capital")
    @portfolio.transactions.create!(kind: "buy", amount: -2000, note: "Bought driver")
    @portfolio.transactions.create!(kind: "sell", amount: 1980, note: "Sold driver (1% fee)")

    results = Fantasy::ReplayTransactions.new(season: @season, dry_run: true).call
    entry = results.find { |r| r[:user] == @user.username }

    assert_equal 4980, entry[:new_cash] # 5000 - 2000 + 1980
  end
end
