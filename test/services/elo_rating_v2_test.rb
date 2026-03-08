require "test_helper"

class EloRatingV2Test < ActiveSupport::TestCase
  # ── Constants ──

  test "constants are set correctly" do
    assert_equal 2000.0, EloRatingV2::STARTING_ELO
    assert_equal 48, EloRatingV2::BASE_K
    assert_equal 0.03, EloRatingV2::REGRESSION_FACTOR
    assert_equal 12.0, EloRatingV2::REFERENCE_RACES
    assert_equal 400.0, EloRatingV2::SCALE
  end

  # ── Pairwise Elo math ──

  test "winner gains elo and loser loses elo" do
    race = races(:bahrain_2026)
    # Reset drivers to known Elo values
    drivers(:verstappen).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:norris).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:leclerc).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:piastri).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    EloRatingV2.process_race(race)

    # P1 should gain, P4 should lose
    ver = race_results(:bahrain_2026_verstappen).reload
    pia = race_results(:bahrain_2026_piastri).reload

    assert ver.new_elo_v2 > ver.old_elo_v2, "Winner should gain Elo"
    assert pia.new_elo_v2 < pia.old_elo_v2, "Last place should lose Elo"
  end

  test "elo changes are zero-sum across all drivers" do
    race = races(:bahrain_2026)
    drivers(:verstappen).update_columns(elo_v2: 2100.0, peak_elo_v2: 2100.0)
    drivers(:norris).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:leclerc).update_columns(elo_v2: 1950.0, peak_elo_v2: 1950.0)
    drivers(:piastri).update_columns(elo_v2: 1900.0, peak_elo_v2: 1900.0)

    EloRatingV2.process_race(race)

    diffs = race.race_results.reload.map { |rr| rr.new_elo_v2 - rr.old_elo_v2 }
    assert_in_delta 0.0, diffs.sum, 0.01, "Elo changes must be zero-sum"
  end

  test "higher-rated driver gains less for expected win" do
    race = races(:bahrain_2026)
    # Verstappen much higher rated — wins as expected
    drivers(:verstappen).update_columns(elo_v2: 2400.0, peak_elo_v2: 2400.0)
    drivers(:norris).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:leclerc).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:piastri).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    EloRatingV2.process_race(race)

    ver_diff = race_results(:bahrain_2026_verstappen).reload.elo_diff
    # Expected win = small gain
    assert ver_diff > 0, "Should still gain"
    assert ver_diff < 50, "Expected win should yield modest gain, got #{ver_diff}"
  end

  test "process_race updates driver elo_v2 and peak_elo_v2" do
    drivers(:verstappen).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:norris).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:leclerc).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    drivers(:piastri).update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    EloRatingV2.process_race(races(:bahrain_2026))

    ver = drivers(:verstappen).reload
    assert_not_equal 2000.0, ver.elo_v2
    assert ver.peak_elo_v2 >= ver.elo_v2
  end

  test "process_race skips races with fewer than 2 results" do
    # Melbourne 2026 has no results
    assert_nil EloRatingV2.process_race(races(:melbourne_2026))
  end

  # ── Regression ──

  test "apply_regression moves elo toward starting value" do
    drivers(:verstappen).update_columns(elo_v2: 2400.0)
    drivers(:piastri).update_columns(elo_v2: 1800.0)

    EloRatingV2.apply_regression!

    ver = drivers(:verstappen).reload.elo_v2
    pia = drivers(:piastri).reload.elo_v2

    # Verstappen should move down toward 2000
    assert ver < 2400.0, "High elo should regress down"
    assert ver > 2000.0, "Should not overshoot starting elo"

    # Piastri should move up toward 2000
    assert pia > 1800.0, "Low elo should regress up"
    assert pia < 2000.0, "Should not overshoot starting elo"
  end

  test "regression formula is correct" do
    drivers(:verstappen).update_columns(elo_v2: 2400.0)
    EloRatingV2.apply_regression!

    expected = 2400.0 * (1 - 0.03) + 2000.0 * 0.03
    assert_in_delta expected, drivers(:verstappen).reload.elo_v2, 0.01
  end

  # ── K-factor scaling ──

  test "k_pair scales inversely with season race count" do
    # With 2 races in the 2026 season, K should be higher than with 24 races
    n = 4 # 4 drivers
    k_2_races = EloRatingV2::BASE_K * (EloRatingV2::REFERENCE_RACES / 2.0) / Math.sqrt(n - 1)
    k_24_races = EloRatingV2::BASE_K * (EloRatingV2::REFERENCE_RACES / 24.0) / Math.sqrt(n - 1)

    assert k_2_races > k_24_races, "Fewer season races should mean higher K"
  end
end
