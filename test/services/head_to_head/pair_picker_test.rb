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

  test "12-round layout progresses through 4 tiers in 3-round segments" do
    @session.update!(rounds_target: 12)
    picker = HeadToHead::PairPicker.new(@session)
    tiers = (0...12).map { |i| picker.tier_for_round(i) }
    assert_equal %w[bottom bottom bottom lower_middle lower_middle lower_middle upper_middle upper_middle upper_middle top top top], tiers
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

  test "pick_diverse_challenger avoids drivers whose team is already seen" do
    picker = HeadToHead::PairPicker.new(@session)
    # Norris is McLaren; Piastri is McLaren too; Leclerc is Ferrari; Verstappen is Red Bull.
    candidates = [drivers(:piastri).id, drivers(:leclerc).id, drivers(:verstappen).id]
    seen = [drivers(:norris).id]  # McLaren is now "seen"
    10.times do
      picked = picker.send(:pick_diverse_challenger, candidates, seen)
      refute_equal drivers(:piastri).id, picked, "should skip the McLaren teammate"
    end
  end

  test "pick_diverse_challenger falls back to any candidate when every team is seen" do
    picker = HeadToHead::PairPicker.new(@session)
    candidates = [drivers(:piastri).id]  # only McLaren left
    seen = [drivers(:norris).id]         # McLaren already seen
    picked = picker.send(:pick_diverse_challenger, candidates, seen)
    assert_equal drivers(:piastri).id, picked
  end
end
