require "test_helper"

class SettingTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "validates key presence" do
    setting = Setting.new(key: nil, value: "test")
    refute setting.valid?
    assert_includes setting.errors[:key], "can't be blank"
  end

  test "validates key uniqueness" do
    Setting.create!(key: "unique_test", value: "one")
    dup = Setting.new(key: "unique_test", value: "two")
    refute dup.valid?
    assert_includes dup.errors[:key], "has already been taken"
  end

  test "get returns value for existing key" do
    Setting.create!(key: "test_key", value: "test_value")
    assert_equal "test_value", Setting.get("test_key")
  end

  test "get returns default when key missing" do
    assert_equal "fallback", Setting.get("nonexistent", "fallback")
  end

  test "get returns nil when key missing and no default" do
    assert_nil Setting.get("nonexistent")
  end

  test "set creates new setting" do
    Setting.set("new_key", "new_value")
    assert_equal "new_value", Setting.find_by(key: "new_key").value
  end

  test "set updates existing setting" do
    Setting.create!(key: "update_key", value: "old")
    Setting.set("update_key", "new")
    assert_equal "new", Setting.find_by(key: "update_key").value
  end

  test "set clears cache" do
    Setting.create!(key: "cached_key", value: "cached")
    Setting.get("cached_key") # warm cache
    Setting.set("cached_key", "updated")
    assert_equal "updated", Setting.get("cached_key")
  end

  test "elo_column returns correct column for known types" do
    assert_equal "peak_elo_v2", Setting.elo_column(:peak_elo)
    assert_equal "elo_v2", Setting.elo_column(:elo)
    assert_equal "new_elo_v2", Setting.elo_column(:new_elo)
    assert_equal "old_elo_v2", Setting.elo_column(:old_elo)
  end

  test "elo_column raises for unknown type" do
    assert_raises(KeyError) { Setting.elo_column(:bogus) }
  end

  test "badge_min_year returns integer" do
    assert_equal 1996, Setting.badge_min_year
  end

  test "fantasy_stock_market? returns false by default" do
    refute Setting.fantasy_stock_market?
  end

  test "fantasy_stock_market? returns true when enabled" do
    Setting.set("fantasy_stock_market", "enabled")
    assert Setting.fantasy_stock_market?
  end

  test "image_source defaults to f1" do
    assert_equal "f1", Setting.image_source
  end

  test "use_wikipedia_images? returns false by default" do
    refute Setting.use_wikipedia_images?
  end

  test "simulated_date returns nil by default" do
    assert_nil Setting.simulated_date
  end

  test "simulated_date parses valid date" do
    Setting.set("simulated_date", "2025-06-15")
    assert_equal Date.new(2025, 6, 15), Setting.simulated_date
  end

  test "simulated_date returns nil for invalid date" do
    Setting.set("simulated_date", "not-a-date")
    assert_nil Setting.simulated_date
  end

  test "effective_today returns today when no simulated date" do
    assert_equal Date.today, Setting.effective_today
  end

  test "effective_today returns simulated date when set" do
    Setting.set("simulated_date", "2025-01-01")
    assert_equal Date.new(2025, 1, 1), Setting.effective_today
  end
end
