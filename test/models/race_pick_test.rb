require "test_helper"

class RacePickTest < ActiveSupport::TestCase
  setup do
    @user = users(:codex)
    @race = races(:melbourne_2026)
  end

  test "valid with user and race" do
    pick = RacePick.new(user: @user, race: @race, picks: [])
    assert pick.valid?
  end

  test "enforces uniqueness per user per race" do
    RacePick.create!(user: @user, race: @race, picks: [])
    duplicate = RacePick.new(user: @user, race: @race, picks: [])
    refute duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "placed_drivers returns sorted by position" do
    pick = RacePick.new(picks: [
      { "driver_id" => 1, "position" => 3, "source" => "manual" },
      { "driver_id" => 2, "position" => 1, "source" => "manual" },
      { "driver_id" => 3, "position" => 2, "source" => "random" }
    ])

    placed = pick.placed_drivers
    assert_equal [1, 2, 3], placed.map { |p| p["position"] }
    assert_equal [2, 3, 1], placed.map { |p| p["driver_id"] }
  end

  test "manual_picks excludes random picks" do
    pick = RacePick.new(picks: [
      { "driver_id" => 1, "position" => 1, "source" => "manual" },
      { "driver_id" => 2, "position" => 2, "source" => "random" },
      { "driver_id" => 3, "position" => 3, "source" => "manual" }
    ])

    manual = pick.manual_picks
    assert_equal 2, manual.size
    assert manual.all? { |p| p["source"] == "manual" }
  end

  test "filled_positions returns count of picks" do
    pick = RacePick.new(picks: [
      { "driver_id" => 1, "position" => 1, "source" => "manual" },
      { "driver_id" => 2, "position" => 2, "source" => "manual" }
    ])
    assert_equal 2, pick.filled_positions
  end

  test "filled_positions returns 0 for nil picks" do
    pick = RacePick.new(picks: nil)
    assert_equal 0, pick.filled_positions
  end

  test "locked? returns false when locked_at is nil" do
    pick = RacePick.new(locked_at: nil)
    refute pick.locked?
  end

  test "locked? returns false when locked_at is in the future" do
    pick = RacePick.new(locked_at: 1.hour.from_now)
    refute pick.locked?
  end

  test "locked? returns true when locked_at is in the past" do
    pick = RacePick.new(locked_at: 1.hour.ago)
    assert pick.locked?
  end

  # ═══════ Associations ═══════

  test "belongs to user" do
    pick = RacePick.create!(user: @user, race: @race, picks: [])
    assert_equal @user, pick.user
  end

  test "belongs to race" do
    pick = RacePick.create!(user: @user, race: @race, picks: [])
    assert_equal @race, pick.race
  end

  # ═══════ Edge cases ═══════

  test "placed_drivers returns empty array for nil picks" do
    pick = RacePick.new(picks: nil)
    assert_equal [], pick.placed_drivers
  end

  test "placed_drivers returns empty array for empty picks" do
    pick = RacePick.new(picks: [])
    assert_equal [], pick.placed_drivers
  end

  test "manual_picks returns empty array for nil picks" do
    pick = RacePick.new(picks: nil)
    assert_equal [], pick.manual_picks
  end

  test "manual_picks returns empty when all random" do
    pick = RacePick.new(picks: [
      { "driver_id" => 1, "position" => 1, "source" => "random" },
      { "driver_id" => 2, "position" => 2, "source" => "random" }
    ])
    assert_equal [], pick.manual_picks
  end

  test "picks can store full grid of 20 drivers" do
    picks_data = (1..20).map do |i|
      { "driver_id" => i, "position" => i, "source" => i <= 10 ? "manual" : "random" }
    end
    pick = RacePick.create!(user: @user, race: @race, picks: picks_data)
    pick.reload
    assert_equal 20, pick.filled_positions
    assert_equal 10, pick.manual_picks.size
  end

  test "locked? returns true when locked_at is exactly now" do
    pick = RacePick.new(locked_at: Time.current)
    assert pick.locked?
  end

  test "allows same user to pick different races" do
    other_race = races(:bahrain_2025)
    RacePick.create!(user: @user, race: @race, picks: [])
    pick2 = RacePick.new(user: @user, race: other_race, picks: [])
    assert pick2.valid?
  end
end
