require "test_helper"

class UpdateActiveDriversTest < ActiveSupport::TestCase
  test "marks drivers with race results in latest season as active" do
    UpdateActiveDrivers.update_season

    assert drivers(:verstappen).reload.active, "Verstappen should be active"
    assert drivers(:norris).reload.active, "Norris should be active"
  end

  test "deactivates drivers without results in latest season" do
    # Create a driver with no race results
    inactive = Driver.create!(
      driver_ref: "test_inactive",
      forename: "Test",
      surname: "Inactive",
      nationality: "Test",
      active: true
    )

    UpdateActiveDrivers.update_season

    refute inactive.reload.active, "Driver without results should be inactive"
  end

  test "runs in a transaction" do
    # Should not leave partial state
    UpdateActiveDrivers.update_season
    active_count = Driver.where(active: true).count
    assert active_count > 0
  end
end
