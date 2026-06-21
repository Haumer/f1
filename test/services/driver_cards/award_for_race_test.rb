require "test_helper"

module DriverCards
  class AwardForRaceTest < ActiveSupport::TestCase
    setup do
      @race = races(:bahrain_2026)
      @user = users(:codex)
      # Fixture finishing order: VER P1, NOR P2, LEC P3, PIA P4.
      @ver = drivers(:verstappen)
      @nor = drivers(:norris)
      @lec = drivers(:leclerc)
      @pia = drivers(:piastri)
      @never_bump = Struct.new(:rand).new(0.99)
    end

    def make_pick(positions, source: "manual")
      RacePick.create!(user: @user, race: @race, picks: positions.map do |driver, pos|
        { "driver_id" => driver.id, "position" => pos, "source" => source }
      end)
    end

    test "awards a card per manually-placed correct pick, snapshots driver stats" do
      make_pick({ @ver => 1, @nor => 2, @lec => 3, @pia => 4 })

      cards = AwardForRace.new(race: @race, rng: @never_bump).call

      assert_equal 4, cards.size
      assert_equal 4, DriverCard.where(user: @user, race: @race).count

      ver_card = DriverCard.find_by(user: @user, race: @race, driver: @ver)
      assert_equal "gold", ver_card.tier # P1 correct, fixture grid not >5
      assert_equal 1, ver_card.predicted_position
      assert_equal 1, ver_card.actual_position
      assert_in_delta @ver.elo_v2.to_f, ver_card.snapshot_elo.to_f, 0.01
      assert_equal (@ver.wins || 0), ver_card.snapshot_wins
      assert_equal (@ver.podiums || 0), ver_card.snapshot_podiums
      assert ver_card.earned_at.present?
    end

    test "does NOT award for random-source picks even if correct" do
      make_pick({ @ver => 1, @nor => 2 }, source: "random")

      assert_no_difference -> { DriverCard.count } do
        AwardForRace.new(race: @race, rng: @never_bump).call
      end
    end

    test "does NOT award when prediction is wrong" do
      make_pick({ @ver => 4, @pia => 1 }) # both swapped

      assert_no_difference -> { DriverCard.count } do
        AwardForRace.new(race: @race, rng: @never_bump).call
      end
    end

    test "is idempotent — running twice does not double-award" do
      make_pick({ @ver => 1, @nor => 2 })

      AwardForRace.new(race: @race, rng: @never_bump).call
      assert_no_difference -> { DriverCard.count } do
        AwardForRace.new(race: @race, rng: @never_bump).call
      end
    end

    test "no race results -> no cards (and no crash)" do
      empty_race = races(:melbourne_2026) # fixture race without results
      make_pick({ @ver => 1 })
      cards = AwardForRace.new(race: empty_race, rng: @never_bump).call
      assert_equal [], cards
    end

    test "ScoreRacePicks call also awards cards" do
      make_pick({ @ver => 1, @nor => 2, @lec => 3, @pia => 4 })

      assert_difference -> { DriverCard.where(user: @user, race: @race).count }, 4 do
        Fantasy::ScoreRacePicks.new(race: @race).call
      end
    end
  end
end
