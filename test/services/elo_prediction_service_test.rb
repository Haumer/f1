require "test_helper"

class EloPredictionServiceTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
    @user = User.create!(
      email: "test@example.com",
      username: "testuser",
      password: "password123",
      terms_accepted: "1"
    )
    @prediction = Prediction.create!(
      race: @race,
      user: @user,
      predicted_results: [
        { "driver_id" => drivers(:verstappen).id, "position" => 1 },
        { "driver_id" => drivers(:norris).id, "position" => 2 },
        { "driver_id" => drivers(:leclerc).id, "position" => 3 },
        { "driver_id" => drivers(:piastri).id, "position" => 4 }
      ]
    )
  end

  test "returns hash keyed by driver_id strings" do
    changes = EloPredictionService.compute(@prediction)
    assert_kind_of Hash, changes
    assert changes.keys.all? { |k| k.is_a?(String) }
  end

  test "each entry has old_elo, new_elo, and diff" do
    changes = EloPredictionService.compute(@prediction)
    changes.each do |_did, entry|
      assert entry.key?("old_elo"), "Missing old_elo"
      assert entry.key?("new_elo"), "Missing new_elo"
      assert entry.key?("diff"), "Missing diff"
    end
  end

  test "predicted winner gains elo" do
    changes = EloPredictionService.compute(@prediction)
    ver_change = changes[drivers(:verstappen).id.to_s]
    assert ver_change["diff"] > 0, "Predicted P1 should gain Elo"
  end

  test "predicted last place loses elo" do
    changes = EloPredictionService.compute(@prediction)
    pia_change = changes[drivers(:piastri).id.to_s]
    assert pia_change["diff"] < 0, "Predicted last should lose Elo"
  end

  test "changes are zero-sum" do
    changes = EloPredictionService.compute(@prediction)
    total_diff = changes.values.sum { |e| e["diff"] }
    assert_in_delta 0.0, total_diff, 0.5, "Prediction Elo changes must be zero-sum"
  end

  test "returns empty hash for fewer than 2 predicted results" do
    @prediction.update!(predicted_results: [
      { "driver_id" => drivers(:verstappen).id, "position" => 1 }
    ])
    assert_equal({}, EloPredictionService.compute(@prediction))
  end

  test "returns empty hash for blank predicted_results" do
    @prediction.update_columns(predicted_results: [])
    assert_equal({}, EloPredictionService.compute(@prediction.reload))
  end

  test "uses driver current elo_v2" do
    changes = EloPredictionService.compute(@prediction)
    ver_id = drivers(:verstappen).id.to_s
    assert_equal drivers(:verstappen).elo_v2.round(1), changes[ver_id]["old_elo"]
  end

  test "uses STARTING_ELO for drivers without elo_v2" do
    rookie = Driver.create!(
      driver_ref: "rookie_test", forename: "Rook", surname: "Ie",
      code: "ROO", number: 99, nationality: "Test", active: true,
      elo_v2: nil
    )
    @prediction.update!(predicted_results: [
      { "driver_id" => rookie.id, "position" => 1 },
      { "driver_id" => drivers(:verstappen).id, "position" => 2 }
    ])

    changes = EloPredictionService.compute(@prediction)
    assert_equal EloRatingV2::STARTING_ELO, changes[rookie.id.to_s]["old_elo"]
  end

  test "k_factor uses total season race count matching real elo engine" do
    # The prediction service should use total season race count (same as the real
    # Elo engine's process_race), NOT the count of completed races before a round.
    # Both R1 and R2 predictions in the same season should use the same K factor.
    mel_prediction = Prediction.create!(
      race: races(:melbourne_2026),
      user: @user,
      predicted_results: @prediction.predicted_results
    )

    bahrain_changes = EloPredictionService.compute(@prediction)
    melbourne_changes = EloPredictionService.compute(mel_prediction)

    # Same drivers, same positions, same season → same K → same diffs
    bahrain_diff = bahrain_changes[drivers(:verstappen).id.to_s]["diff"]
    melbourne_diff = melbourne_changes[drivers(:verstappen).id.to_s]["diff"]
    assert_in_delta bahrain_diff, melbourne_diff, 0.01,
      "Same season, same matchup should produce identical diffs regardless of round"
  end
end
