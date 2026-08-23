require "test_helper"

class CircuitsControllerTest < ActionDispatch::IntegrationTest
  test "index returns 200" do
    get circuits_path
    assert_response :success
  end

  test "show returns 200" do
    get circuit_path(circuits(:bahrain))
    assert_response :success
  end

  test "index renders the season journey map with a stop per round" do
    travel_to Time.zone.parse("2026-03-15 12:00") do
      get circuits_path
      assert_response :success

      assert_select "[data-controller=?]", "circuit-map" do |elements|
        stops = JSON.parse(elements.first["data-circuit-map-stops-value"])
        legs  = JSON.parse(elements.first["data-circuit-map-legs-value"])

        assert_equal Race.where(season: seasons(:season_2026)).count, stops.size
        assert_equal stops.size - 1, legs.size

        bahrain = stops.find { |s| s["name"] == circuits(:bahrain).name }
        assert_equal [circuits(:bahrain).lng, circuits(:bahrain).lat], bahrain["coord"]
        assert bahrain["past"], "a race on 2026-03-08 should be in the past on 2026-03-15"
        assert_equal circuit_path(circuits(:bahrain)), bahrain["path"]

        # Melbourne is 2026-03-22 — still to come, so it is the next round and
        # its inbound leg is the one the map animates.
        melbourne = stops.find { |s| s["name"] == circuits(:melbourne).name }
        assert_not melbourne["past"]
        assert_nil melbourne["winner"]
        assert_equal ["next"], legs.map { |l| l["state"] }
      end
    end
  end

  test "index omits the map when the season has fewer than two rounds" do
    # Cancelling rather than destroying — races are referenced by fantasy
    # entries, and Race's default scope already hides cancelled rounds.
    Race.where(season: seasons(:season_2026))
        .where.not(id: races(:bahrain_2026).id)
        .update_all(cancelled: true)

    get circuits_path
    assert_response :success
    assert_select "[data-controller=?]", "circuit-map", 0
  end

  # A leg from Suzuka to Miami is shorter across the Pacific, but drawn in
  # projected coordinates it runs backwards across Eurasia. These legs get cut
  # at the map edge and resumed on the far side.
  test "legs crossing the antimeridian are split at the map edge" do
    controller = CircuitsController.new
    suzuka = [136.541, 34.8431]
    miami  = [-80.2389, 25.9581]

    segments = controller.send(:antimeridian_split, suzuka, miami)

    assert_equal 2, segments.size
    (first_coords, first_curved), (second_coords, second_curved) = segments

    assert_equal suzuka, first_coords.first
    assert_equal 180.0, first_coords.last.first
    assert_equal(-180.0, second_coords.first.first)
    assert_equal miami, second_coords.last

    # The two halves must meet at the same latitude or the line visibly jumps.
    assert_equal first_coords.last.last, second_coords.first.last

    # Straight, not curved — a curve would bow the halves away from the edge.
    assert_not first_curved
    assert_not second_curved
  end

  test "legs inside one hemisphere are left as a single curved arc" do
    controller = CircuitsController.new
    monza = [9.28111, 45.6156]
    spa   = [5.97139, 50.4372]

    segments = controller.send(:antimeridian_split, monza, spa)

    assert_equal [[[monza, spa], true]], segments
  end
end
