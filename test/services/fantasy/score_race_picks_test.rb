require "test_helper"

module Fantasy
  class ScoreRacePicksTest < ActiveSupport::TestCase
    setup do
      @race   = races(:bahrain_2026)
      @user   = users(:codex)
      @wallet = fantasy_portfolios(:codex_2026)
      @stock  = fantasy_stock_portfolios(:codex_stock_2026)

      # Fixtures already define the finishing order: VER P1, NOR P2, LEC P3, PIA P4.
      @order = [drivers(:verstappen), drivers(:norris), drivers(:leclerc), drivers(:piastri)]
    end

    def make_pick(positions)
      # positions: { driver => predicted_position }
      RacePick.create!(user: @user, race: @race, picks: positions.map do |driver, pos|
        { "driver_id" => driver.id, "position" => pos, "source" => "manual" }
      end)
    end

    test "perfect prediction scores all-exact plus podium bonus and pays credits" do
      make_pick(@order.each_with_index.to_h { |d, i| [d, i + 1] })

      before = @wallet.cash
      Fantasy::ScoreRacePicks.new(race: @race).call

      # 4 exact (25 each) + perfect podium bonus (25) = 125 pts
      assert_equal 125, RacePick.find_by(user: @user, race: @race).score
      reward = @stock.transactions.find_by(race: @race, kind: "pick_reward")
      assert reward, "a pick_reward transaction is created"
      assert_equal 250.0, reward.amount # 125 * CREDITS_PER_POINT (2.0)
      assert_equal before + 250.0, @wallet.reload.cash
    end

    test "distance-based scoring without a perfect podium" do
      # VER P2 (off by 1 -> 15), NOR P1 (off by 1 -> 15), LEC P3 (exact -> 25), PIA P10 (off by 6 -> 0)
      make_pick(drivers(:verstappen) => 2, drivers(:norris) => 1,
                drivers(:leclerc) => 3, drivers(:piastri) => 10)

      Fantasy::ScoreRacePicks.new(race: @race).call

      assert_equal 55, RacePick.find_by(user: @user, race: @race).score
      assert_equal 110.0, @stock.transactions.find_by(race: @race, kind: "pick_reward").amount
    end

    test "is idempotent — re-running does not double-pay" do
      make_pick(@order.each_with_index.to_h { |d, i| [d, i + 1] })

      Fantasy::ScoreRacePicks.new(race: @race).call
      cash_after_first = @wallet.reload.cash

      Fantasy::ScoreRacePicks.new(race: @race).call
      assert_equal cash_after_first, @wallet.reload.cash
      assert_equal 1, @stock.transactions.where(race: @race, kind: "pick_reward").count
    end

    test "zero-scoring picks set score but pay no reward" do
      # Everyone predicted far from actual finish
      make_pick(drivers(:verstappen) => 20, drivers(:norris) => 19)

      Fantasy::ScoreRacePicks.new(race: @race).call

      assert_equal 0, RacePick.find_by(user: @user, race: @race).score
      assert_nil @stock.transactions.find_by(race: @race, kind: "pick_reward")
    end

    test "does nothing when the race has no results" do
      RaceResult.where(race: @race).delete_all
      make_pick(@order.each_with_index.to_h { |d, i| [d, i + 1] })

      assert_nothing_raised { Fantasy::ScoreRacePicks.new(race: @race).call }
      assert_nil RacePick.find_by(user: @user, race: @race).score
    end
  end
end
