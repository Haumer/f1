require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "elo_tier returns nil for nil input" do
    assert_nil elo_tier(nil)
  end

  test "elo_tier returns Elite for 2600+" do
    tier = elo_tier(2650)
    assert_equal "Elite", tier[:label]
    assert_equal "elite", tier[:css]
  end

  test "elo_tier returns World Class for 2450-2599" do
    tier = elo_tier(2500)
    assert_equal "World Class", tier[:label]
    assert_equal "world-class", tier[:css]
  end

  test "elo_tier returns Strong for 2300-2449" do
    tier = elo_tier(2350)
    assert_equal "Strong", tier[:label]
    assert_equal "strong", tier[:css]
  end

  test "elo_tier returns Average for 2100-2299" do
    tier = elo_tier(2200)
    assert_equal "Average", tier[:label]
    assert_equal "average", tier[:css]
  end

  test "elo_tier returns Developing for below 2100" do
    tier = elo_tier(1900)
    assert_equal "Developing", tier[:label]
    assert_equal "developing", tier[:css]
  end

  test "elo_tier boundary at 2600" do
    assert_equal "Elite", elo_tier(2600)[:label]
    assert_equal "World Class", elo_tier(2599)[:label]
  end

  test "finished? helper returns true for Finished" do
    assert finished?("Finished")
  end

  test "finished? helper returns true for lapped status" do
    assert finished?("+1 Lap")
  end

  test "finished? helper returns false for blank" do
    refute finished?("")
    refute finished?(nil)
  end

  test "finished? helper returns false for Retired" do
    refute finished?("Retired")
  end

  test "hex_to_rgb converts hex to rgb string" do
    assert_equal "255, 0, 0", hex_to_rgb("#FF0000")
  end

  test "hex_to_rgb handles hex without hash" do
    assert_equal "0, 128, 255", hex_to_rgb("0080FF")
  end

  test "hex_to_rgb returns default for blank" do
    assert_equal "225, 6, 0", hex_to_rgb(nil)
    assert_equal "225, 6, 0", hex_to_rgb("")
  end
end
