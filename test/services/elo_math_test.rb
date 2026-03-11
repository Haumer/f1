require "test_helper"

class EloMathTest < ActiveSupport::TestCase
  test "SCALE constant is 400" do
    assert_equal 400.0, EloMath::SCALE
  end

  # ── compute_k_pair ──

  test "compute_k_pair scales inversely with season_races" do
    k_short = EloMath.compute_k_pair(48, 12.0, 6, 4)
    k_long = EloMath.compute_k_pair(48, 12.0, 24, 4)
    assert k_short > k_long, "Fewer races should yield higher K"
  end

  test "compute_k_pair scales inversely with grid size" do
    k_small = EloMath.compute_k_pair(48, 12.0, 12, 4)
    k_large = EloMath.compute_k_pair(48, 12.0, 12, 20)
    assert k_small > k_large, "Smaller grid should yield higher K"
  end

  test "compute_k_pair matches expected formula" do
    # k = base_k * (reference_races / season_races) / sqrt(n - 1)
    expected = 48 * (12.0 / 20.0) / Math.sqrt(9)
    actual = EloMath.compute_k_pair(48, 12.0, 20, 10)
    assert_in_delta expected, actual, 0.001
  end

  # ── pairwise_adjustments ──

  test "pairwise adjustments are zero-sum for two equal players" do
    participants = [
      { id: 1, elo: 2000.0, score: 1 },
      { id: 2, elo: 2000.0, score: 2 }
    ]
    adj = EloMath.pairwise_adjustments(participants, 10.0)
    assert_in_delta 0.0, adj[1] + adj[2], 0.001
  end

  test "winner gains and loser loses elo" do
    participants = [
      { id: 1, elo: 2000.0, score: 1 },
      { id: 2, elo: 2000.0, score: 2 }
    ]
    adj = EloMath.pairwise_adjustments(participants, 10.0)
    assert adj[1] > 0, "Winner should gain"
    assert adj[2] < 0, "Loser should lose"
  end

  test "expected win yields smaller gain" do
    participants = [
      { id: 1, elo: 2400.0, score: 1 },
      { id: 2, elo: 2000.0, score: 2 }
    ]
    adj_expected = EloMath.pairwise_adjustments(participants, 10.0)

    participants2 = [
      { id: 1, elo: 2000.0, score: 1 },
      { id: 2, elo: 2400.0, score: 2 }
    ]
    adj_upset = EloMath.pairwise_adjustments(participants2, 10.0)

    assert adj_expected[1] < adj_upset[1],
      "Expected win gain (#{adj_expected[1]}) should be less than upset win gain (#{adj_upset[1]})"
  end

  test "zero-sum with multiple participants" do
    participants = [
      { id: 1, elo: 2300.0, score: 1 },
      { id: 2, elo: 2200.0, score: 2 },
      { id: 3, elo: 2100.0, score: 3 },
      { id: 4, elo: 2000.0, score: 4 }
    ]
    adj = EloMath.pairwise_adjustments(participants, 10.0)
    assert_in_delta 0.0, adj.values.sum, 0.001
  end

  test "tied scores split the expected points" do
    participants = [
      { id: 1, elo: 2000.0, score: 1 },
      { id: 2, elo: 2000.0, score: 1 }
    ]
    adj = EloMath.pairwise_adjustments(participants, 10.0)
    # Equal elo, tied score => no change
    assert_in_delta 0.0, adj[1], 0.001
    assert_in_delta 0.0, adj[2], 0.001
  end
end
