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
