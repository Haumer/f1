require "test_helper"

class FantasyRosterEntryTest < ActiveSupport::TestCase
  setup do
    @active_entry = fantasy_roster_entries(:codex_verstappen)
    @sold_entry = fantasy_roster_entries(:codex_leclerc_sold)
  end

  # Associations
  test "belongs to fantasy_portfolio" do
    assert_equal fantasy_portfolios(:codex_2026), @active_entry.fantasy_portfolio
  end

  test "belongs to driver" do
    assert_equal drivers(:verstappen), @active_entry.driver
  end

  test "belongs to bought_race" do
    assert_equal races(:bahrain_2026), @active_entry.bought_race
  end

  test "sold entry belongs to sold_race" do
    assert_equal races(:melbourne_2026), @sold_entry.sold_race
  end

  # Validations
  test "validates bought_at_elo presence" do
    entry = FantasyRosterEntry.new(fantasy_portfolio: fantasy_portfolios(:codex_2026),
                                    driver: drivers(:piastri),
                                    bought_at_elo: nil)
    refute entry.valid?
    assert_includes entry.errors[:bought_at_elo], "can't be blank"
  end

  # Scopes
  test "active scope returns only active entries" do
    active = FantasyRosterEntry.where(fantasy_portfolio: fantasy_portfolios(:codex_2026)).active
    assert active.all?(&:active)
    assert_equal 2, active.count
  end

  test "sold scope returns only sold entries" do
    sold = FantasyRosterEntry.where(fantasy_portfolio: fantasy_portfolios(:codex_2026)).sold
    assert sold.none?(&:active)
    assert_equal 1, sold.count
  end

  # current_value
  test "current_value uses Fantasy::Pricing" do
    expected = Fantasy::Pricing.price_for(drivers(:verstappen), seasons(:season_2026))
    assert_in_delta expected, @active_entry.current_value, 0.01
  end

  # gain_loss
  test "gain_loss is current_value minus bought_at_elo" do
    expected = @active_entry.current_value - @active_entry.bought_at_elo
    assert_in_delta expected, @active_entry.gain_loss, 0.01
  end

  # gain_loss_percent
  test "gain_loss_percent returns percentage" do
    expected = (@active_entry.gain_loss / @active_entry.bought_at_elo * 100).round(1)
    assert_in_delta expected, @active_entry.gain_loss_percent, 0.1
  end

  test "gain_loss_percent returns 0 when bought_at_elo is zero" do
    @active_entry.bought_at_elo = 0.0
    assert_equal 0, @active_entry.gain_loss_percent
  end
end
