require "test_helper"

class CircuitTest < ActiveSupport::TestCase
  # ── Validations ──

  test "requires name" do
    c = Circuit.new(circuit_ref: "test")
    assert_not c.valid?
    assert_includes c.errors[:name], "can't be blank"
  end

  test "requires circuit_ref" do
    c = Circuit.new(name: "Test Circuit")
    assert_not c.valid?
    assert_includes c.errors[:circuit_ref], "can't be blank"
  end

  test "circuit_ref must be unique" do
    dupe = Circuit.new(name: "Fake Bahrain", circuit_ref: "bahrain")
    assert_not dupe.valid?
    assert_includes dupe.errors[:circuit_ref], "has already been taken"
  end

  # ── Custom methods ──

  test "to_param returns circuit_ref" do
    assert_equal "bahrain", circuits(:bahrain).to_param
  end

  test "track_image_path returns svg path" do
    assert_equal "circuits/bahrain.svg", circuits(:bahrain).track_image_path
  end

  # ── Associations ──

  test "has races" do
    assert circuits(:bahrain).races.any?
  end
end
