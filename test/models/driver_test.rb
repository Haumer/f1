require "test_helper"

class DriverTest < ActiveSupport::TestCase
  # ── Validations ──

  test "requires surname" do
    driver = Driver.new(driver_ref: "test_driver")
    assert_not driver.valid?
    assert_includes driver.errors[:surname], "can't be blank"
  end

  test "requires driver_ref" do
    driver = Driver.new(surname: "Test")
    assert_not driver.valid?
    assert_includes driver.errors[:driver_ref], "can't be blank"
  end

  test "valid driver" do
    assert drivers(:verstappen).valid?
  end

  # ── Scopes ──

  test "active scope returns only active drivers" do
    active = Driver.active
    assert active.all?(&:active?)
    assert_includes active, drivers(:verstappen)
  end

  test "by_peak_elo orders descending" do
    ordered = Driver.by_peak_elo.to_a
    assert ordered.each_cons(2).all? { |a, b|
      (a.peak_elo_v2 || 0) >= (b.peak_elo_v2 || 0)
    }
  end

  # ── Custom methods ──

  test "fullname returns forename and surname" do
    assert_equal "Max Verstappen", drivers(:verstappen).fullname
  end

  test "display_elo returns elo_v2" do
    assert_equal drivers(:verstappen).elo_v2, drivers(:verstappen).display_elo
  end

  test "current_constructor returns most recent season constructor" do
    assert_equal constructors(:red_bull), drivers(:verstappen).current_constructor
  end

  test "constructor_for returns constructor for given season" do
    assert_equal constructors(:mclaren), drivers(:norris).constructor_for(seasons(:season_2026))
  end

  test "peak_elo_race_result returns result with highest new_elo_v2" do
    peak = drivers(:verstappen).peak_elo_race_result
    assert_not_nil peak
    assert_equal peak.new_elo_v2, drivers(:verstappen).race_results.maximum(:new_elo_v2)
  end

  # ── Associations ──

  test "has race results" do
    assert drivers(:verstappen).race_results.any?
  end

  test "has seasons through season_drivers" do
    assert_includes drivers(:verstappen).seasons, seasons(:season_2026)
  end

  test "has constructors through season_drivers" do
    assert_includes drivers(:verstappen).constructors, constructors(:red_bull)
  end
end
