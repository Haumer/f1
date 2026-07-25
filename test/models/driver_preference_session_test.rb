require "test_helper"

class DriverPreferenceSessionTest < ActiveSupport::TestCase
  setup do
    @session = DriverPreferenceSession.create!(
      session_token: "t-#{SecureRandom.hex(4)}",
      year: 2026,
      started_at: Time.current,
      rounds_target: 4,
    )
    @a = drivers(:verstappen)
    @b = drivers(:norris)
    @c = drivers(:leclerc)
    @d = drivers(:piastri)
  end

  test "top_ranked ranks final champion first, then losers in reverse elimination order" do
    # Sequence: A beats B; A beats C; D beats A; D beats @c? — we only have 4
    # drivers, so replay: A beats B; A beats C; D beats A. Final champion is D.
    add_match(0, winner: @a, loser: @b)
    add_match(1, winner: @a, loser: @c)
    add_match(2, winner: @d, loser: @a)

    ids = @session.top_ranked.map(&:id)
    assert_equal [@d.id, @a.id, @c.id, @b.id], ids
  end

  test "top_ranked demotes an early king who was later beaten" do
    # Norris wins twice, then loses to Verstappen. Verstappen should outrank
    # Norris even though Norris has more wins.
    add_match(0, winner: @b, loser: @c)
    add_match(1, winner: @b, loser: @d)
    add_match(2, winner: @a, loser: @b)

    ids = @session.top_ranked.map(&:id)
    assert_equal @a.id, ids.first, "final champion should be #1"
    assert ids.index(@a.id) < ids.index(@b.id), "beat-later ranks above beaten-earlier"
  end

  private

  def add_match(round, winner:, loser:)
    @session.matches.create!(
      winner_driver: winner, loser_driver: loser,
      year: 2026, round_index: round,
      tier: "bottom", created_at: Time.current,
    )
  end
end
