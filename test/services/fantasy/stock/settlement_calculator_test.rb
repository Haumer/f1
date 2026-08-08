require "test_helper"

class Fantasy::Stock::SettlementCalculatorTest < ActiveSupport::TestCase
  Calc = Fantasy::Stock::SettlementCalculator

  test "constructor_multiplier_for_position ranges 0.5 to 5.0 linearly" do
    assert_in_delta 0.5, Calc.constructor_multiplier_for_position(1), 1e-9
    assert_in_delta 5.0, Calc.constructor_multiplier_for_position(10), 1e-9
    # Midpoint: pos 5 → 0.5 + 4 * (4.5/9) = 0.5 + 2.0 = 2.5
    assert_in_delta 2.5, Calc.constructor_multiplier_for_position(5), 1e-9
  end

  test "constructor_multiplier_for_position clamps out-of-range positions" do
    assert_equal Calc.constructor_multiplier_for_position(1),  Calc.constructor_multiplier_for_position(-3)
    assert_equal Calc.constructor_multiplier_for_position(10), Calc.constructor_multiplier_for_position(99)
  end

  test "default_constructor_multiplier is WCC P5 (2.5)" do
    assert_in_delta 2.5, Calc.default_constructor_multiplier, 1e-9
  end

  test "dividend_breakdown returns per_share 0 for finishes outside top 10" do
    breakdown = Calc.dividend_breakdown(constructor_mult: 2.5, elo_rank: 3, position: 11)
    assert_equal 0.0, breakdown[:per_share]
  end

  test "dividend_breakdown returns per_share 0 for nil position (DNF)" do
    breakdown = Calc.dividend_breakdown(constructor_mult: 2.5, elo_rank: 3, position: nil)
    assert_equal 0.0, breakdown[:per_share]
  end

  test "dividend_breakdown base pay: constructor_mult × BASE, no overperformance" do
    # elo_rank == position → no overperformance bonus
    breakdown = Calc.dividend_breakdown(constructor_mult: 2.5, elo_rank: 3, position: 3)
    assert_in_delta 0.25, breakdown[:per_share], 1e-9 # 2.5 * 0.10
    assert_equal 0, breakdown[:overperformance]
  end

  test "dividend_breakdown adds surprise bonus for overperformance" do
    # elo_rank 15 finishes P3 → overperformance = 12
    breakdown = Calc.dividend_breakdown(constructor_mult: 5.0, elo_rank: 15, position: 3)
    # 5.0 * 0.10 + 0.02 * 12 = 0.5 + 0.24 = 0.74
    assert_in_delta 0.74, breakdown[:per_share], 1e-9
    assert_equal 12, breakdown[:overperformance]
  end

  test "borrow_fee_per_share is 0.25% of entry price" do
    assert_in_delta 0.25, Calc.borrow_fee_per_share(entry_price: 100.0), 1e-9
  end

  test "margin_call_price triples the entry price" do
    assert_in_delta 300.0, Calc.margin_call_price(entry_price: 100.0), 1e-9
  end
end
