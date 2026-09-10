require "test_helper"

class ConstructorEloV2Test < ActiveSupport::TestCase
  setup do
    # Clear pre-computed constructor elo so idempotency guard doesn't skip
    Race.find(races(:bahrain_2026).id).race_results.update_all(
      old_constructor_elo_v2: nil, new_constructor_elo_v2: nil
    )
  end

  test "constants are set correctly" do
    assert_equal 2000.0, ConstructorEloV2::STARTING_ELO
    assert_equal 32, ConstructorEloV2::BASE_K
    assert_equal 12.0, ConstructorEloV2::REFERENCE_RACES
    assert_equal "average finishing position", ConstructorEloV2::SCORING_METHOD
  end

  test "process_race updates constructor elo" do
    constructors(:red_bull).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:mclaren).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:ferrari).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    ConstructorEloV2.process_race(races(:bahrain_2026))

    rb = constructors(:red_bull).reload
    assert_not_equal 2000.0, rb.elo_v2, "Red Bull elo should change"
    assert rb.peak_elo_v2 >= rb.elo_v2
  end

  test "process_race writes old and new constructor elo on race results" do
    constructors(:red_bull).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:mclaren).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:ferrari).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    ConstructorEloV2.process_race(races(:bahrain_2026))

    rr = race_results(:bahrain_2026_verstappen).reload
    assert rr.old_constructor_elo_v2.present?
    assert rr.new_constructor_elo_v2.present?
  end

  test "process_race is idempotent — skips already processed race" do
    constructors(:red_bull).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:mclaren).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:ferrari).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    ConstructorEloV2.process_race(races(:bahrain_2026))
    elo_after_first = constructors(:red_bull).reload.elo_v2

    ConstructorEloV2.process_race(races(:bahrain_2026))
    elo_after_second = constructors(:red_bull).reload.elo_v2

    assert_equal elo_after_first, elo_after_second, "Second call should be a no-op"
  end

  test "process_race skips races with no results" do
    assert_nil ConstructorEloV2.process_race(races(:melbourne_2026))
  end

  test "constructor elo changes are zero-sum" do
    constructors(:red_bull).update_columns(elo_v2: 2100.0, peak_elo_v2: 2100.0)
    constructors(:mclaren).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:ferrari).update_columns(elo_v2: 1950.0, peak_elo_v2: 1950.0)

    ConstructorEloV2.process_race(races(:bahrain_2026))

    race = races(:bahrain_2026)
    results = race.race_results.reload
    by_constructor = results.group_by(&:constructor_id)

    total_change = by_constructor.sum do |_, rrs|
      rr = rrs.first
      (rr.new_constructor_elo_v2 || 0) - (rr.old_constructor_elo_v2 || 0)
    end
    assert_in_delta 0.0, total_change, 0.01, "Constructor Elo changes must be zero-sum"
  end

  test "uses average finish so constructors with different entry counts are comparable" do
    constructors(:red_bull).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:mclaren).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    constructors(:ferrari).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    # McLaren finishes P2 and P4 (average P3); Ferrari has one entry at P3.
    # They should tie even though McLaren has twice as many classified cars.
    ConstructorEloV2.process_race(races(:bahrain_2026))

    assert_in_delta constructors(:mclaren).reload.elo_v2,
                    constructors(:ferrari).reload.elo_v2,
                    0.001
  end

  test "initial rating remains the peak when a constructor loses on debut" do
    constructors(:red_bull).update_columns(elo_v2: nil, peak_elo_v2: nil)
    constructors(:mclaren).update_columns(elo_v2: nil, peak_elo_v2: nil)
    constructors(:ferrari).update_columns(elo_v2: nil, peak_elo_v2: nil)

    ConstructorEloV2.process_race(races(:bahrain_2026))

    assert_equal ConstructorEloV2::STARTING_ELO, constructors(:ferrari).reload.peak_elo_v2
  end

  test "full simulation clears stale ratings that are outside valid race history" do
    inactive = Constructor.create!(
      constructor_ref: "never_started",
      name: "Never Started Racing",
      nationality: "Austrian",
      elo_v2: 2400.0,
      peak_elo_v2: 2500.0
    )

    ConstructorEloV2.simulate_all!

    assert_nil inactive.reload.elo_v2
    assert_nil inactive.peak_elo_v2
  end

  test "dry-run simulation calculates its scope without changing ratings" do
    constructor = constructors(:red_bull)
    constructor.update_columns(elo_v2: 2345.0, peak_elo_v2: 2456.0)

    result = ConstructorEloV2.simulate_all!(persist: false)

    assert_operator result[:constructors_updated], :>, 0
    assert_operator result[:race_results_updated], :>, 0
    assert_equal 2345.0, constructor.reload.elo_v2
    assert_equal 2456.0, constructor.peak_elo_v2
  end
end
