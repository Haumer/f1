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

      # 4 exact (50 each) + perfect podium bonus (50) = 250 pts, paid 1:1
      assert_equal 250, RacePick.find_by(user: @user, race: @race).score
      reward = @stock.transactions.find_by(race: @race, kind: "pick_reward")
      assert reward, "a pick_reward transaction is created"
      assert_equal 250, reward.amount # points == credits
      assert_equal before + 250, @wallet.reload.cash
    end

    test "distance-based scoring without a perfect podium" do
      # VER P2 (off by 1 -> 30), NOR P1 (off by 1 -> 30), LEC P3 (exact -> 50), PIA P10 (off by 6 -> 0)
      make_pick(drivers(:verstappen) => 2, drivers(:norris) => 1,
                drivers(:leclerc) => 3, drivers(:piastri) => 10)

      Fantasy::ScoreRacePicks.new(race: @race).call

      assert_equal 110, RacePick.find_by(user: @user, race: @race).score
      assert_equal 110, @stock.transactions.find_by(race: @race, kind: "pick_reward").amount
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

    # ── breakdown (shared by the settler and the scorecard view) ──

    test "breakdown returns per-driver rows, exact count, podium bonus and total" do
      placed = [
        { "driver_id" => drivers(:verstappen).id, "position" => 1 }, # exact
        { "driver_id" => drivers(:norris).id,     "position" => 3 }, # actual P2 -> off by 1
        { "driver_id" => drivers(:leclerc).id,    "position" => 3 }, # exact
      ]
      finish = { drivers(:verstappen).id => 1, drivers(:norris).id => 2, drivers(:leclerc).id => 3 }

      b = Fantasy::ScoreRacePicks.breakdown(placed, finish)

      assert_equal [50, 30, 50], b[:rows].map(&:points)
      assert_equal [true, false, true], b[:rows].map(&:hit?)
      assert_equal 2, b[:exact]
      assert_equal 0, b[:podium_bonus] # NOR wrong -> podium not perfect
      assert_equal 130, b[:total]
    end

    test "breakdown awards the podium bonus only for an exact P1-P2-P3" do
      placed = [
        { "driver_id" => drivers(:verstappen).id, "position" => 1 },
        { "driver_id" => drivers(:norris).id,     "position" => 2 },
        { "driver_id" => drivers(:leclerc).id,    "position" => 3 },
      ]
      finish = { drivers(:verstappen).id => 1, drivers(:norris).id => 2, drivers(:leclerc).id => 3 }

      b = Fantasy::ScoreRacePicks.breakdown(placed, finish)
      assert_equal 50, b[:podium_bonus]
      assert_equal 200, b[:total] # 50*3 + 50 bonus
    end

    test "breakdown marks an unraced pick as a miss with nil actual" do
      placed = [{ "driver_id" => drivers(:verstappen).id, "position" => 1 }]
      b = Fantasy::ScoreRacePicks.breakdown(placed, {})

      assert_nil b[:rows].first.actual
      assert_equal 0, b[:rows].first.points
      assert_equal 0, b[:total]
    end

    # ── scoring cutoff (P11+ zeros when scoring_limit is set) ──

    test "breakdown with scoring_limit zeros points for picks outside the top N" do
      placed = [
        { "driver_id" => drivers(:verstappen).id, "position" => 1 },  # exact, in zone
        { "driver_id" => drivers(:norris).id,     "position" => 11 }, # would be off-by-9 anyway
        { "driver_id" => drivers(:leclerc).id,    "position" => 18 }, # exact-but-out-of-zone
      ]
      finish = {
        drivers(:verstappen).id => 1,
        drivers(:norris).id     => 2,
        drivers(:leclerc).id    => 18,
      }

      b = Fantasy::ScoreRacePicks.breakdown(placed, finish, scoring_limit: 10)

      assert_equal [50, 0, 0], b[:rows].map(&:points)
      assert_equal [false, true, true], b[:rows].map(&:out_of_zone)
      # Leclerc still counts as an "exact hit" for the hit counter — it just earns nothing.
      assert_equal 2, b[:exact]
      assert_equal 50, b[:total]
    end

    test "breakdown without scoring_limit preserves old all-positions scoring" do
      placed = [{ "driver_id" => drivers(:verstappen).id, "position" => 18 }]
      finish = { drivers(:verstappen).id => 18 }

      b = Fantasy::ScoreRacePicks.breakdown(placed, finish)
      assert_equal 50, b[:rows].first.points
      assert_equal false, b[:rows].first.out_of_zone
    end

    test "scoring_limit_for returns nil for pre-cutoff races and SCORING_TOP_N after" do
      pre  = Race.new(date: Fantasy::ScoreRacePicks::RULE_EFFECTIVE_DATE - 1)
      post = Race.new(date: Fantasy::ScoreRacePicks::RULE_EFFECTIVE_DATE)

      assert_nil Fantasy::ScoreRacePicks.scoring_limit_for(pre)
      assert_equal Fantasy::ScoreRacePicks::SCORING_TOP_N,
                   Fantasy::ScoreRacePicks.scoring_limit_for(post)
    end

    test "settler zeros P11+ picks on a post-cutoff race" do
      @race.update_column(:date, Fantasy::ScoreRacePicks::RULE_EFFECTIVE_DATE + 1)
      # VER P1 (exact, in zone, 50 pts) + LEC P11 (off by 8, but cutoff anyway → 0)
      RacePick.create!(user: @user, race: @race, picks: [
        { "driver_id" => drivers(:verstappen).id, "position" => 1, "source" => "manual" },
        { "driver_id" => drivers(:leclerc).id,    "position" => 11, "source" => "manual" },
      ])

      Fantasy::ScoreRacePicks.new(race: @race).call

      assert_equal 50, RacePick.find_by(user: @user, race: @race).score
      assert_equal 50, @stock.transactions.find_by(race: @race, kind: "pick_reward").amount
    end
  end
end
