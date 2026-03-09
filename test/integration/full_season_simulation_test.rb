require "test_helper"

# Full-season integration test: simulates a 10-race season with 6 drivers,
# processes Elo after every race, runs both fantasy portfolio and stock market
# systems, then validates the entire pipeline end-to-end.
class FullSeasonSimulationTest < ActiveSupport::TestCase
  RACE_COUNT = 10
  DRIVER_COUNT = 6

  setup do
    # Isolate from fixtures — use a fresh season
    @season = Season.create!(year: 2099)
    @circuit = circuits(:bahrain)

    # Create 6 drivers, all starting at 2000 Elo
    @drivers = DRIVER_COUNT.times.map do |i|
      Driver.create!(
        driver_ref: "sim_driver_#{i}",
        forename: "Driver",
        surname: "#{('A'..'Z').to_a[i]}",
        code: "D#{i}X",
        number: 50 + i,
        nationality: "Test",
        active: true,
        elo_v2: EloRatingV2::STARTING_ELO,
        peak_elo_v2: EloRatingV2::STARTING_ELO
      )
    end

    # Link drivers to season with constructors
    constructors = [constructors(:mclaren), constructors(:red_bull), constructors(:ferrari)]
    @drivers.each_with_index do |driver, i|
      SeasonDriver.create!(driver: driver, season: @season, constructor: constructors[i % 3])
    end

    # Create 10 races
    @races = RACE_COUNT.times.map do |i|
      Race.create!(
        year: 2099,
        round: i + 1,
        date: Date.new(2099, 3, 1) + (i * 14).days,
        time: "15:00:00",
        circuit: @circuit,
        season: @season,
        season_end: i == RACE_COUNT - 1
      )
    end

    @finished = statuses(:finished)
    @retired = statuses(:retired)

    # Create user + fantasy portfolio
    @user = User.create!(
      email: "simuser@example.com",
      password: "password123",
      username: "simuser",
      terms_accepted: "1"
    )
  end

  test "full season: Elo, fantasy portfolio, and stock market all work end-to-end" do
    # ─── Phase 1: Process 10 races with Elo ───
    finishing_orders = generate_finishing_orders
    cumulative_points = Hash.new(0.0)

    @races.each_with_index do |race, race_idx|
      order = finishing_orders[race_idx]
      create_race_results(race, order)
      EloRatingV2.process_race(race)
      update_standings(race, order, cumulative_points)
    end

    # ─── Verify Elo outcomes ───
    verify_elo_integrity(finishing_orders)

    # ─── Phase 2: Fantasy portfolio simulation ───
    simulate_fantasy_portfolio

    # ─── Phase 3: Fantasy stock market simulation ───
    simulate_stock_portfolio

    # ─── Phase 4: Season-end regression ───
    verify_season_end_regression
  end

  private

  # Generate deterministic but varied finishing orders.
  # Driver 0 dominates, Driver 5 is worst. Middle drivers shuffle.
  def generate_finishing_orders
    RACE_COUNT.times.map do |race_idx|
      order = @drivers.dup
      # Dominant driver (0) always top-2, worst driver (5) always bottom-2
      # Middle drivers get shuffled with a seeded RNG for determinism
      rng = Random.new(race_idx * 42)
      middle = order[1..4].shuffle(random: rng)
      if race_idx.even?
        [order[0]] + middle + [order[5]]
      else
        # Occasionally let driver 1 win
        [middle[0], order[0]] + middle[1..] + [order[5]]
      end
    end
  end

  def create_race_results(race, finishing_order)
    points_table = [25, 18, 15, 12, 10, 8]
    finishing_order.each_with_index do |driver, pos|
      status = pos < 5 ? @finished : (rand(3) == 0 ? @retired : @finished)
      RaceResult.create!(
        race: race,
        driver: driver,
        constructor: driver.season_drivers.find_by(season: @season).constructor,
        grid: pos + 1,
        position: pos + 1,
        position_order: pos + 1,
        points: points_table[pos] || 0,
        laps: 57,
        status: status
      )
    end
  end

  def update_standings(race, finishing_order, cumulative_points)
    points_table = [25, 18, 15, 12, 10, 8]
    finishing_order.each_with_index do |driver, pos|
      cumulative_points[driver.id] += points_table[pos] || 0
    end

    sorted = cumulative_points.sort_by { |_, pts| -pts }
    sorted.each_with_index do |(driver_id, pts), rank|
      DriverStanding.create!(
        race: race,
        driver_id: driver_id,
        points: pts,
        position: rank + 1,
        wins: finishing_order[0].id == driver_id ? 1 : 0,
        season_end: race.season_end?
      )
    end
  end

  def verify_elo_integrity(finishing_orders)
    @drivers.each(&:reload)

    # 1. Every driver should have an Elo (no nils)
    @drivers.each do |d|
      assert d.elo_v2.present?, "#{d.surname} should have an Elo after #{RACE_COUNT} races"
      assert d.peak_elo_v2.present?, "#{d.surname} should have a peak Elo"
    end

    # 2. Peak Elo >= current Elo
    @drivers.each do |d|
      assert d.peak_elo_v2 >= d.elo_v2, "#{d.surname} peak (#{d.peak_elo_v2}) should be >= current (#{d.elo_v2})"
    end

    # 3. The dominant driver (0) should have the highest Elo
    dominant = @drivers[0]
    worst = @drivers[5]
    assert dominant.elo_v2 > worst.elo_v2,
      "Dominant driver (#{dominant.elo_v2}) should have higher Elo than worst (#{worst.elo_v2})"

    # 4. Every race result should have old/new Elo recorded
    RaceResult.where(race: @races).each do |rr|
      assert rr.old_elo_v2.present?, "RaceResult ##{rr.id} missing old_elo_v2"
      assert rr.new_elo_v2.present?, "RaceResult ##{rr.id} missing new_elo_v2"
    end

    # 5. Zero-sum: total Elo adjustments per race should net to ~0
    @races.each do |race|
      results = RaceResult.where(race: race)
      total_change = results.sum { |rr| rr.new_elo_v2 - rr.old_elo_v2 }
      assert_in_delta 0.0, total_change, 0.5,
        "Race #{race.round} Elo changes should be zero-sum (got #{total_change.round(3)})"
    end

    # 6. Elo should separate — the spread shouldn't be zero
    elos = @drivers.map(&:elo_v2)
    spread = elos.max - elos.min
    assert spread > 50, "Expected meaningful Elo spread after #{RACE_COUNT} races, got #{spread.round(1)}"

    # 7. Standings exist for every race
    @races.each do |race|
      assert_equal DRIVER_COUNT, DriverStanding.where(race: race).count,
        "Race #{race.round} should have #{DRIVER_COUNT} driver standings"
    end

    # 8. Season-end standings: position 1 should have most points
    final_standings = DriverStanding.where(race: @races.last).order(:position)
    assert final_standings.first.points >= final_standings.last.points
  end

  def simulate_fantasy_portfolio
    # Create portfolio before first race
    result = Fantasy::CreatePortfolio.new(user: @user, season: @season).call
    portfolio = result[:portfolio]
    assert portfolio, "Portfolio should be created"
    initial_capital = portfolio.starting_capital
    assert initial_capital > 0, "Starting capital should be positive"

    # Buy 2 drivers before race 1
    race1 = @races[0]
    race1.update_columns(date: 1.week.from_now.to_date)
    buy1 = Fantasy::BuyDriver.new(portfolio: portfolio, driver: @drivers[0], race: race1).call
    assert buy1[:success], "Should buy driver 0: #{buy1[:error]}"
    buy2 = Fantasy::BuyDriver.new(portfolio: portfolio, driver: @drivers[1], race: race1).call
    assert buy2[:success], "Should buy driver 1: #{buy2[:error]}"
    race1.update_columns(date: Date.new(2099, 3, 1)) # reset

    assert portfolio.reload.active_roster_entries.count == 2
    assert portfolio.cash < initial_capital, "Cash should decrease after buying"

    # Snapshot after each race — interleave with Elo changes
    # (Elo was already processed in Phase 1, so snapshot values reflect final Elo.
    #  Re-run process_race to restore the incremental Elo per race for snapshots.)
    # Instead, just snapshot — the values will differ because driver elos were updated
    # incrementally during Phase 1. Re-snapshot now to capture the final state per race.
    # To get varied snapshots, tweak driver elo between snapshots to simulate incremental.
    @drivers.each { |d| d.update_columns(elo_v2: EloRatingV2::STARTING_ELO) }
    @races.each do |race|
      # Restore the Elo as of this race from race results
      RaceResult.where(race: race).each do |rr|
        rr.driver.update_columns(elo_v2: rr.new_elo_v2) if rr.new_elo_v2
      end
      Fantasy::SnapshotPortfolios.new(race: race).call
    end

    assert_equal RACE_COUNT, portfolio.snapshots.count, "Should have #{RACE_COUNT} snapshots"

    # Snapshots should have ranked values
    portfolio.snapshots.each do |snap|
      assert snap.value.present?, "Snapshot for race #{snap.race_id} missing value"
      assert snap.rank.present?, "Snapshot for race #{snap.race_id} missing rank"
    end

    # Portfolio value should track driver Elo changes
    first_snap = portfolio.snapshots.order(:created_at).first
    last_snap = portfolio.snapshots.order(:created_at).last
    assert first_snap.value != last_snap.value,
      "Portfolio value should change over the season (first: #{first_snap.value}, last: #{last_snap.value})"

    # Leaderboard should work
    board = Fantasy::Leaderboard.new(season: @season).call
    assert board.any?, "Leaderboard should have entries"
    assert_equal portfolio, board.first[:portfolio]

    # Check achievements — should earn at least first_trade
    earned = Fantasy::CheckAchievements.new(portfolio: portfolio, race: @races.last).call
    keys = earned.compact.map(&:key)
    assert_includes keys, "first_trade"

    # Sell a driver (use a future race, and ensure held_races >= 1)
    sell_race = @races.last
    sell_race.update_columns(date: 1.week.from_now.to_date)
    sell_result = Fantasy::SellDriver.new(portfolio: portfolio, driver: @drivers[1], race: sell_race).call
    assert sell_result[:success], "Should sell driver 1: #{sell_result[:error]}"
    sell_race.update_columns(date: Date.new(2099, 3, 1) + (9 * 14).days) # reset

    portfolio.reload
    assert_equal 1, portfolio.active_roster_entries.count
    assert portfolio.transactions.where(kind: "sell").exists?

    # Buy a team to expand roster
    team_race = @races[2]
    team_race.update_columns(date: 1.week.from_now.to_date)
    team_result = Fantasy::BuyTeam.new(portfolio: portfolio, race: team_race).call
    assert team_result[:success], "Should buy team: #{team_result[:error]}"
    team_race.update_columns(date: Date.new(2099, 3, 1) + (2 * 14).days) # reset
    assert_equal 4, portfolio.reload.roster_slots
  end

  def simulate_stock_portfolio
    result = Fantasy::Stock::CreatePortfolio.new(user: @user, season: @season).call
    portfolio = result[:portfolio]
    assert portfolio, "Stock portfolio should be created"
    assert portfolio.starting_capital > 0

    # Buy shares in dominant driver
    buy_race = @races[0]
    buy_race.update_columns(date: 1.week.from_now.to_date)
    buy_result = Fantasy::Stock::BuyShares.new(
      portfolio: portfolio, driver: @drivers[0], quantity: 3, race: buy_race
    ).call
    assert buy_result[:success], "Should buy shares: #{buy_result[:error]}"

    # Open a short on worst driver
    short_result = Fantasy::Stock::OpenShort.new(
      portfolio: portfolio, driver: @drivers[5], quantity: 2, race: buy_race
    ).call
    assert short_result[:success], "Should open short: #{short_result[:error]}"
    buy_race.update_columns(date: Date.new(2099, 3, 1))

    portfolio.reload
    assert_equal 2, portfolio.active_holdings.count
    assert_equal 1, portfolio.active_longs.count
    assert_equal 1, portfolio.active_shorts.count
    assert portfolio.total_collateral > 0, "Short should lock collateral"

    # Settle each race (dividends, borrow fees, margin checks, snapshots)
    @races.each do |race|
      Fantasy::Stock::SettleRace.new(race: race).call
    end

    portfolio.reload

    # Should have snapshots for every race
    assert_equal RACE_COUNT, portfolio.snapshots.count,
      "Stock portfolio should have #{RACE_COUNT} snapshots"

    # Should have dividend transactions (driver 0 finishes top consistently)
    dividend_txs = portfolio.transactions.where(kind: "dividend")
    assert dividend_txs.any?, "Should have earned dividends from top-finishing driver"

    # Should have borrow fee transactions
    borrow_txs = portfolio.transactions.where(kind: "borrow_fee")
    assert borrow_txs.any?, "Should have borrow fee charges for short position"

    # Portfolio snapshots should track value over time
    snap_values = portfolio.snapshots.pluck(:value)
    assert snap_values.all? { |v| v.is_a?(Numeric) && v >= 0 },
      "All snapshot values should be non-negative numbers"

    # Sell shares
    sell_race = @races.last
    sell_race.update_columns(date: 1.week.from_now.to_date)

    long_holding = portfolio.active_longs.first
    if long_holding
      sell_result = Fantasy::Stock::SellShares.new(
        portfolio: portfolio, driver: long_holding.driver, quantity: 1, race: sell_race
      ).call
      assert sell_result[:success], "Should sell 1 share: #{sell_result[:error]}"
    end

    # Close short
    short_holding = portfolio.active_shorts.first
    if short_holding
      close_result = Fantasy::Stock::CloseShort.new(
        portfolio: portfolio, driver: short_holding.driver, quantity: short_holding.quantity, race: sell_race
      ).call
      assert close_result[:success], "Should close short: #{close_result[:error]}"
    end
    sell_race.update_columns(date: Date.new(2099, 3, 1) + (9 * 14).days)

    portfolio.reload
    assert_equal 0, portfolio.active_shorts.count, "All shorts should be closed"

    # Check achievements
    earned = Fantasy::Stock::CheckAchievements.new(portfolio: portfolio).call
    keys = earned.compact.map(&:key)
    assert_includes keys, "first_stock_trade"
    assert_includes keys, "first_long"
    assert_includes keys, "first_short"
  end

  def verify_season_end_regression
    elos_before = @drivers.map { |d| [d.id, d.reload.elo_v2] }.to_h

    EloRatingV2.apply_regression!

    @drivers.each do |d|
      d.reload
      expected = elos_before[d.id] * (1 - EloRatingV2::REGRESSION_FACTOR) + EloRatingV2::STARTING_ELO * EloRatingV2::REGRESSION_FACTOR
      assert_in_delta expected, d.elo_v2, 0.01,
        "#{d.surname} regression incorrect: expected #{expected.round(2)}, got #{d.elo_v2.round(2)}"
    end

    # After regression, all Elos should be closer to STARTING_ELO
    @drivers.each do |d|
      old = elos_before[d.id]
      new_elo = d.elo_v2
      if old > EloRatingV2::STARTING_ELO
        assert new_elo < old, "#{d.surname} above-average Elo should decrease after regression"
      elsif old < EloRatingV2::STARTING_ELO
        assert new_elo > old, "#{d.surname} below-average Elo should increase after regression"
      end
    end
  end
end
