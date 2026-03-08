require "test_helper"

class ConstructorFamiliesTest < ActiveSupport::TestCase
  test "family_for returns family name for known constructor" do
    family = Constructor.family_for(constructors(:mclaren))
    assert_equal "McLaren", family
  end

  test "family_for returns family name for red_bull" do
    family = Constructor.family_for(constructors(:red_bull))
    assert_equal "Red Bull", family
  end

  test "family_for returns family name for ferrari" do
    family = Constructor.family_for(constructors(:ferrari))
    assert_equal "Ferrari", family
  end

  test "family_for returns constructor name for unknown ref" do
    unknown = Constructor.new(constructor_ref: "unknown_team", name: "Unknown Team")
    assert_equal "Unknown Team", Constructor.family_for(unknown)
  end

  test "family_members returns constructors for known family" do
    members = Constructor.family_members("McLaren")
    assert_includes members.pluck(:constructor_ref), "mclaren"
  end

  test "family_members returns none for unknown family" do
    assert_equal 0, Constructor.family_members("Nonexistent").count
  end

  test "family_members returns none for nil-refs family" do
    result = Constructor.family_members("BAR / Honda / Brawn / Mercedes")
    assert_equal 0, result.count
  end

  test "lineages returns LINEAGES hash" do
    lineages = Constructor.lineages
    assert lineages.key?("Mercedes")
    assert lineages.key?("Red Bull Racing")
    assert_kind_of Hash, lineages["Mercedes"]
    assert_includes lineages["Mercedes"][:chain], "brawn"
  end

  test "FAMILIES constant is frozen" do
    assert Constructor::FAMILIES.frozen?
  end

  test "LINEAGES constant is frozen" do
    assert Constructor::LINEAGES.frozen?
  end
end
