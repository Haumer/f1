require "test_helper"

class FantasyStockHoldingTest < ActiveSupport::TestCase
  setup do
    @long = fantasy_stock_holdings(:codex_ver_long)
    @short = fantasy_stock_holdings(:codex_nor_short)
    @closed = fantasy_stock_holdings(:codex_lec_closed)
  end

  # Associations
  test "belongs to fantasy_stock_portfolio" do
    assert_equal fantasy_stock_portfolios(:codex_stock_2026), @long.fantasy_stock_portfolio
  end

  test "belongs to driver" do
    assert_equal drivers(:verstappen), @long.driver
  end

  test "belongs to opened_race" do
    assert_equal races(:bahrain_2026), @long.opened_race
  end

  test "closed holding belongs to closed_race" do
    assert_equal races(:melbourne_2026), @closed.closed_race
  end

  # Validations
  test "validates quantity greater than 0" do
    @long.quantity = 0
    refute @long.valid?
  end

  test "validates direction inclusion" do
    @long.direction = "sideways"
    refute @long.valid?
    assert_includes @long.errors[:direction], "is not included in the list"
  end

  test "validates entry_price presence" do
    @long.entry_price = nil
    refute @long.valid?
  end

  # Scopes
  test "active scope" do
    active = FantasyStockHolding.where(fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026)).active
    assert_equal 2, active.count
  end

  test "longs scope" do
    longs = FantasyStockHolding.where(fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026)).longs
    assert longs.all? { |h| h.direction == "long" }
  end

  test "shorts scope" do
    shorts = FantasyStockHolding.where(fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026)).shorts
    assert shorts.all? { |h| h.direction == "short" }
  end

  # long? / short?
  test "long? returns true for long holding" do
    assert @long.long?
    refute @long.short?
  end

  test "short? returns true for short holding" do
    assert @short.short?
    refute @short.long?
  end

  # current_price
  test "current_price delegates to portfolio share_price" do
    expected = @long.fantasy_stock_portfolio.share_price(drivers(:verstappen))
    assert_in_delta expected, @long.current_price, 0.01
  end

  # market_value for long
  test "market_value for long is current_price * quantity" do
    expected = @long.current_price * @long.quantity
    assert_in_delta expected, @long.market_value, 0.01
  end

  # market_value for short
  test "market_value for short is (entry_price - current_price) * quantity" do
    expected = (@short.entry_price - @short.current_price) * @short.quantity
    assert_in_delta expected, @short.market_value, 0.01
  end

  # gain_loss for long
  test "gain_loss for long is (current - entry) * quantity" do
    expected = (@long.current_price - @long.entry_price) * @long.quantity
    assert_in_delta expected, @long.gain_loss, 0.01
  end

  # gain_loss for short
  test "gain_loss for short is (entry - current) * quantity" do
    expected = (@short.entry_price - @short.current_price) * @short.quantity
    assert_in_delta expected, @short.gain_loss, 0.01
  end

  # gain_loss_percent
  test "gain_loss_percent calculates correctly" do
    total_cost = @long.entry_price * @long.quantity
    expected = (@long.gain_loss / total_cost * 100).round(1)
    assert_in_delta expected, @long.gain_loss_percent, 0.1
  end

  test "gain_loss_percent returns 0 when entry_price is zero" do
    @long.entry_price = 0.0
    assert_equal 0, @long.gain_loss_percent
  end
end
