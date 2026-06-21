require "test_helper"

module DriverCards
  class CombineTest < ActiveSupport::TestCase
    setup do
      @user = users(:codex)
      @driver = drivers(:verstappen)
      @races = [
        races(:bahrain_2025),
        races(:melbourne_2025),
        races(:bahrain_2026)
      ]
    end

    def seed_cards(tier:, count:, races: @races)
      count.times.map do |i|
        DriverCard.create!(
          user: @user,
          driver: @driver,
          race: races[i],
          predicted_position: 1,
          actual_position: 1,
          tier: tier,
          snapshot_wins: 50 + i,
          snapshot_podiums: 100 + i,
          snapshot_wdc: 3,
          snapshot_elo: 1800.0 + i,
          earned_at: (3 - i).days.ago
        )
      end
    end

    test "combines 3 bronze cards into 1 silver" do
      seed_cards(tier: "bronze", count: 3)

      result = nil
      assert_difference -> { DriverCard.where(user: @user, driver: @driver).count }, -2 do
        result = Combine.call(user: @user, driver: @driver, tier: "bronze")
      end

      assert_equal "silver", result.tier
      assert_equal @driver, result.driver
      assert_equal @user, result.user
      assert_equal 3, result.combined_from_race_ids.size
      assert result.combined?
      assert_equal 0, DriverCard.where(user: @user, driver: @driver, tier: "bronze").count
      assert_equal 1, DriverCard.where(user: @user, driver: @driver, tier: "silver").count
    end

    test "new card inherits most-recent contributor's race and snapshots" do
      seed_cards(tier: "silver", count: 3)
      newest_source = DriverCard.where(user: @user, driver: @driver, tier: "silver").order(:earned_at).last
      expected_race = newest_source.race
      expected_wins = newest_source.snapshot_wins

      result = Combine.call(user: @user, driver: @driver, tier: "silver")

      assert_equal expected_race, result.race
      assert_equal expected_wins, result.snapshot_wins
      assert_equal "gold", result.tier
    end

    test "raises when fewer than 3 cards of the tier exist" do
      seed_cards(tier: "bronze", count: 2)

      assert_no_difference -> { DriverCard.count } do
        assert_raises(Combine::Error) do
          Combine.call(user: @user, driver: @driver, tier: "bronze")
        end
      end
    end

    test "raises when combining legendary (no next tier)" do
      seed_cards(tier: "legendary", count: 3)

      assert_no_difference -> { DriverCard.count } do
        assert_raises(Combine::Error) do
          Combine.call(user: @user, driver: @driver, tier: "legendary")
        end
      end
    end

    test "leaves newest extras alone when more than 3 cards exist" do
      seed_cards(tier: "bronze", count: 3)
      # 4th bronze on a different race, NEWER than all seeded ones.
      extra_race = races(:melbourne_2026)
      DriverCard.create!(
        user: @user,
        driver: @driver,
        race: extra_race,
        predicted_position: 2,
        actual_position: 2,
        tier: "bronze",
        snapshot_wins: 99,
        snapshot_podiums: 99,
        snapshot_wdc: 3,
        snapshot_elo: 1900.0,
        earned_at: 1.hour.ago
      )

      Combine.call(user: @user, driver: @driver, tier: "bronze")

      remaining_bronzes = DriverCard.where(user: @user, driver: @driver, tier: "bronze")
      assert_equal 1, remaining_bronzes.count
      # The newest bronze (not in oldest-3) survives.
      assert_equal extra_race, remaining_bronzes.first.race
    end
  end
end
