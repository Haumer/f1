require "test_helper"

class ConstructorTest < ActiveSupport::TestCase
  # ── Validations ──

  test "requires name" do
    c = Constructor.new(constructor_ref: "test")
    assert_not c.valid?
    assert_includes c.errors[:name], "can't be blank"
  end

  test "requires constructor_ref" do
    c = Constructor.new(name: "Test Racing")
    assert_not c.valid?
    assert_includes c.errors[:constructor_ref], "can't be blank"
  end

  test "constructor_ref must be unique" do
    dupe = Constructor.new(name: "Fake McLaren", constructor_ref: "mclaren")
    assert_not dupe.valid?
    assert_includes dupe.errors[:constructor_ref], "has already been taken"
  end

  # ── Custom methods ──

  test "to_param returns constructor_ref" do
    assert_equal "mclaren", constructors(:mclaren).to_param
  end

  test "display_elo returns elo_v2" do
    assert_equal constructors(:red_bull).elo_v2, constructors(:red_bull).display_elo
  end

  # ── Associations ──

  test "has race results" do
    assert constructors(:red_bull).race_results.any?
  end

  test "has season_drivers" do
    assert constructors(:mclaren).season_drivers.any?
  end

  # ── Constants ──

  test "COLORS hash contains current grid teams" do
    assert Constructor::COLORS.key?(:mclaren)
    assert Constructor::COLORS.key?(:red_bull)
    assert Constructor::COLORS.key?(:ferrari)
  end
end
