require "test_helper"

class HeadToHead::CrowdRankerTest < ActiveSupport::TestCase
  setup do
    @year = 2099
    @session = DriverPreferenceSession.create!(
      session_token: "crowd-#{SecureRandom.hex(4)}",
      year: @year,
      started_at: Time.current,
      rounds_target: 3,
    )
    @drivers = 4.times.map do |i|
      ref = "crd_test_#{SecureRandom.hex(4)}_#{i}"
      Driver.create!(driver_ref: ref, forename: "Test", surname: "Driver#{i}", elo_v2: 1500)
    end
  end

  def record_match(round, winner, loser, tier: "mid")
    DriverPreferenceMatch.create!(
      driver_preference_session: @session,
      year: @year,
      round_index: round,
      tier: tier,
      winner_driver: winner,
      loser_driver: loser,
    )
  end

  test "opponent-adjusted score breaks the raw-pct tie in favor of beating the stronger driver" do
    top, mid_a, mid_b, bottom = @drivers
    # Session: mid_b beats bottom, mid_a beats mid_b, top beats mid_a
    record_match(0, mid_b, bottom)
    record_match(1, mid_a, mid_b)
    record_match(2, top, mid_a)

    rows = HeadToHead::CrowdRanker.call(@year)
    ranking = rows.map(&:driver)

    assert_equal top, ranking[0], "top should be #1"
    assert_equal mid_a, ranking[1], "mid_a beat mid_b (50%) so outranks mid_b who beat bottom (0%)"
    assert_equal mid_b, ranking[2]
    assert_equal bottom, ranking[3]

    mid_a_row = rows.find { |r| r.driver == mid_a }
    mid_b_row = rows.find { |r| r.driver == mid_b }
    assert_equal 0.5, mid_a_row.pct
    assert_equal 0.5, mid_b_row.pct
    assert mid_a_row.score > mid_b_row.score,
      "mid_a's score should beat mid_b's despite identical 50% pct — opponent quality differs"
  end

  test "beats mid-tier win-farming: a mid who racks up wins vs bottom loses to a top-beater" do
    top, farmer, victim1, victim2 = @drivers
    # farmer beats victim1 and victim2 (both weak), then loses to top
    record_match(0, farmer, victim1)
    record_match(1, farmer, victim2)
    record_match(2, top, farmer)

    rows = HeadToHead::CrowdRanker.call(@year)
    top_row    = rows.find { |r| r.driver == top }
    farmer_row = rows.find { |r| r.driver == farmer }

    assert_equal 1.0, top_row.pct
    assert_in_delta 0.667, farmer_row.pct, 0.01

    # top beat a farmer whose pct is ~0.67 -> big +
    # farmer's 2 wins were against 0%-pct victims -> tiny +; loss to 100%-pct top -> zero
    assert top_row.score > farmer_row.score,
      "top's single high-quality win must outrank farmer's two low-quality wins"
  end

  test "returns [] when no matches exist" do
    assert_equal [], HeadToHead::CrowdRanker.call(@year)
  end

  test "crowd_score is a 0-100 integer derived from raw score" do
    a, b, _, _ = @drivers
    record_match(0, a, b) # a beats b (both 100% and 0% pct respectively)

    rows = HeadToHead::CrowdRanker.call(@year)
    a_row = rows.find { |r| r.driver == a }
    b_row = rows.find { |r| r.driver == b }

    assert_kind_of Integer, a_row.crowd_score
    assert_operator a_row.crowd_score, :>=, 0
    assert_operator a_row.crowd_score, :<=, 100
    # a beat b (pct 0) => raw +0.0 => score 50
    assert_equal 50, a_row.crowd_score
    # b lost to a (pct 1.0) => raw -(1-1.0) = 0 => score 50
    assert_equal 50, b_row.crowd_score
  end

  test "podium_eligible? requires PODIUM_MIN_TOTAL picks" do
    a, b, c, _ = @drivers
    record_match(0, a, b)
    record_match(1, a, c)
    record_match(2, a, b)

    rows = HeadToHead::CrowdRanker.call(@year)
    a_row = rows.find { |r| r.driver == a }  # total 3
    b_row = rows.find { |r| r.driver == b }  # total 2
    c_row = rows.find { |r| r.driver == c }  # total 1

    assert_equal 3, a_row.total
    assert_equal 2, b_row.total
    assert_equal 1, c_row.total
    assert a_row.podium_eligible?, "a meets the 3-pick floor"
    refute b_row.podium_eligible?, "b under the 3-pick floor"
    refute c_row.podium_eligible?, "c under the 3-pick floor"
  end

  test "display_rank is assigned 1..N to eligible drivers only; ineligible get nil and sort to the end" do
    a, b, c, d = @drivers
    # a: 3 wins (eligible). b: 2 losses (ineligible). c: 1 loss (ineligible).
    # d: 1 win over a (ineligible, but would have highest score of any driver)
    record_match(0, a, b)
    record_match(1, a, c)
    record_match(2, a, b)
    record_match(3, d, a)

    rows = HeadToHead::CrowdRanker.call(@year)
    a_row = rows.find { |r| r.driver == a }
    b_row = rows.find { |r| r.driver == b }
    c_row = rows.find { |r| r.driver == c }
    d_row = rows.find { |r| r.driver == d }

    # Only a is eligible (4 picks); everyone else < 3.
    assert_equal 1, a_row.display_rank
    assert_nil b_row.display_rank
    assert_nil c_row.display_rank
    assert_nil d_row.display_rank

    # Eligible rows must precede ineligible rows in the returned order,
    # regardless of raw score. Otherwise the table numbering desyncs from the podium.
    eligible_indices = rows.each_with_index.filter_map { |r, i| i if r.podium_eligible? }
    ineligible_indices = rows.each_with_index.filter_map { |r, i| i unless r.podium_eligible? }
    assert eligible_indices.max < ineligible_indices.min,
      "all eligible rows must appear before any ineligible row"
  end

  test "ignores matches from other years" do
    a, b, _, _ = @drivers
    record_match(0, a, b)
    DriverPreferenceMatch.create!(
      driver_preference_session: @session,
      year: @year - 1,
      round_index: 99,
      tier: "mid",
      winner_driver: b,
      loser_driver: a,
    )
    rows = HeadToHead::CrowdRanker.call(@year)
    a_row = rows.find { |r| r.driver == a }
    assert_equal 1, a_row.wins
    assert_equal 0, a_row.losses
  end
end
