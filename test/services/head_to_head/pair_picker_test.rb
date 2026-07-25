require "test_helper"

class HeadToHead::PairPickerTest < ActiveSupport::TestCase
  setup do
    @session = DriverPreferenceSession.create!(
      session_token: "test-#{SecureRandom.hex(4)}",
      year: 2026,
      started_at: Time.current,
      rounds_target: 10,
    )
  end

  test "pool is ordered by elo descending and drops drivers without elo" do
    pool = HeadToHead::PairPicker.pool_for(2026)
    assert pool.size >= 2
    elos = pool.map(&:elo_v2)
    assert_equal elos.sort.reverse, elos
    assert pool.none? { |d| d.elo_v2.nil? }
  end

  test "tier ramp progresses bottom then middle then top" do
    picker = HeadToHead::PairPicker.new(@session)
    tiers = (0...10).map { |i| picker.tier_for_round(i) }
    assert_equal %w[bottom bottom bottom middle middle middle middle top top top], tiers
  end

  test "first pair with no champion draws both drivers from the pool" do
    pair = HeadToHead::PairPicker.new(@session).next_pair
    assert_not_nil pair
    assert pair.champion.is_a?(Driver)
    assert pair.challenger.is_a?(Driver)
    refute_equal pair.champion.id, pair.challenger.id
  end

  test "returns nil once the session is full" do
    @session.update!(rounds_played: 10)
    assert_nil HeadToHead::PairPicker.new(@session).next_pair
  end

  test "champion is preserved when set and challenger differs" do
    driver = HeadToHead::PairPicker.pool_for(2026).first
    @session.update!(champion_driver_id: driver.id, rounds_played: 1)
    pair = HeadToHead::PairPicker.new(@session).next_pair
    assert_equal driver.id, pair.champion.id
    refute_equal driver.id, pair.challenger.id
  end
end
