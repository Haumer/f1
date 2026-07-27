require "test_helper"

module DriverCards
  class ResolveTierTest < ActiveSupport::TestCase
    # Stub RNG that never rolls the 10% bump.
    NEVER_BUMP = Struct.new(:rand).new(0.99)
    # Stub RNG that always rolls the 10% bump.
    ALWAYS_BUMP = Struct.new(:rand).new(0.0)

    test "no card when prediction != actual" do
      assert_nil ResolveTier.call(predicted: 2, actual: 3, grid: 5, rng: NEVER_BUMP)
    end

    test "no card when finish is outside top 10" do
      assert_nil ResolveTier.call(predicted: 11, actual: 11, grid: 12, rng: NEVER_BUMP)
    end

    test "P4..10 correct -> Bronze (no bump)" do
      (4..10).each do |pos|
        assert_equal "bronze", ResolveTier.call(predicted: pos, actual: pos, grid: 10, rng: NEVER_BUMP)
      end
    end

    test "P4..10 correct + bump -> Silver" do
      assert_equal "silver", ResolveTier.call(predicted: 7, actual: 7, grid: 10, rng: ALWAYS_BUMP)
    end

    test "P2 or P3 correct -> Silver (no bump)" do
      assert_equal "silver", ResolveTier.call(predicted: 2, actual: 2, grid: 5, rng: NEVER_BUMP)
      assert_equal "silver", ResolveTier.call(predicted: 3, actual: 3, grid: 5, rng: NEVER_BUMP)
    end

    test "P2 or P3 correct + bump -> Gold" do
      assert_equal "gold", ResolveTier.call(predicted: 2, actual: 2, grid: 5, rng: ALWAYS_BUMP)
    end

    test "P1 correct from front-half grid -> Gold" do
      assert_equal "gold", ResolveTier.call(predicted: 1, actual: 1, grid: 3, rng: NEVER_BUMP)
    end

    test "P1 correct from front-half grid + bump -> Platinum" do
      assert_equal "platinum", ResolveTier.call(predicted: 1, actual: 1, grid: 1, rng: ALWAYS_BUMP)
    end

    test "P1 correct from grid > 5 is an upset -> Platinum" do
      assert_equal "platinum", ResolveTier.call(predicted: 1, actual: 1, grid: 11, rng: NEVER_BUMP)
    end

    test "P1 upset + bump -> Legendary" do
      assert_equal "legendary", ResolveTier.call(predicted: 1, actual: 1, grid: 17, rng: ALWAYS_BUMP)
    end

    test "missing grid does not crash and treats as non-upset" do
      assert_equal "gold", ResolveTier.call(predicted: 1, actual: 1, grid: nil, rng: NEVER_BUMP)
    end
  end
end
