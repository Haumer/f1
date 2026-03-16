require "test_helper"

# Full-season integration test: simulates a 10-race season with 6 drivers,
# processes Elo after every race, runs the fantasy stock market system,
# then validates the entire pipeline end-to-end.
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

  test "full season: Elo and stock market all work end-to-end" do
    # --- Phase 1: Process 10 races with Elo ---
    finishing_orders = generate_finishing_orders
    cumulative_points = Hash.new(0.0)

    @races.each_with_index do |race, race_idx|
      order = finishing_orders[race_idx]
      create_race_results(race, order)
      EloRatingV2.process_race(race)
      update_standings(race, order, cumulative_points)
    end

    # --- Verify Elo outcomes ---
    verify_elo_integrity(finishing_orders)

    # --- Phase 2: Fantasy portfolio + stock market simulation ---
    simulate_portfolio_and_stock
  end

  private

  # Generate deterministic but varied finishing orders.
  # Driver 0 dominates, Driver 5 is worst. Middle drivers shuffle.
  def generate_finishing_orders
    RACE_COUNT.times.map do |race_idx|
      order = @drivers.dup
      rng = Random.new(race_idx * 42)
      middle = order[1..4].shuffle(random: rng)
      if race_idx.even?
        [order[0]] + middle + [order[5]]
      else
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

  def simulate_portfolio_and_stock
    # Create portfolio (auto-creates stock portfolio)
    result = Fantasy::CreatePortfolio.new(user: @user, season: @season).call
    portfolio = result[:portfolio]
    assert portfolio, "Portfolio should be created"
    initial_capital = portfolio.starting_capital
    assert initial_capital > 0, "Starting capital should be positive"

    # Get the auto-created stock portfolio
    stock_portfolio = @user.fantasy_stock_portfolio_for(@season)
    assert stock_portfolio, "Stock portfolio should be auto-created"

    # Buy shares in dominant driver
    buy_race = @races[0]
    buy_race.update_columns(date: 1.week.from_now.to_date)
    buy_result = Fantasy::Stock::BuyShares.new(
      portfolio: stock_portfolio, driver: @drivers[0], quantity: 3, race: buy_race
    ).call
    assert buy_result[:success], "Should buy shares: #{buy_result[:error]}"

    # Buy shares in another driver
    buy_result2 = Fantasy::Stock::BuyShares.new(
      portfolio: stock_portfolio, driver: @drivers[1], quantity: 2, race: buy_race
    ).call
    assert buy_result2[:success], "Should buy shares in driver 1: #{buy_result2[:error]}"

    # Open a short on worst driver
    short_result = Fantasy::Stock::OpenShort.new(
      portfolio: stock_portfolio, driver: @drivers[5], quantity: 2, race: buy_race
    ).call
    assert short_result[:success], "Should open short: #{short_result[:error]}"
    buy_race.update_columns(date: Date.new(2099, 3, 1))

    stock_portfolio.reload
    assert stock_portfolio.active_holdings.count >= 2
    assert stock_portfolio.active_longs.count >= 1
    assert stock_portfolio.active_shorts.count >= 1

    # Snapshot portfolio and settle stock each race
    @drivers.each { |d| d.update_columns(elo_v2: EloRatingV2::STARTING_ELO) }
    @races.each do |race|
      RaceResult.where(race: race).each do |rr|
        rr.driver.update_columns(elo_v2: rr.new_elo_v2) if rr.new_elo_v2
      end
      Fantasy::SnapshotPortfolios.new(race: race).call
      Fantasy::Stock::SettleRace.new(race: race).call
    end

    assert_equal RACE_COUNT, portfolio.snapshots.count, "Should have #{RACE_COUNT} snapshots"

    # Snapshots should have ranked values
    portfolio.snapshots.each do |snap|
      assert snap.value.present?, "Snapshot for race #{snap.race_id} missing value"
      assert snap.rank.present?, "Snapshot for race #{snap.race_id} missing rank"
    end

    # Stock portfolio should have snapshots too
    assert_equal RACE_COUNT, stock_portfolio.snapshots.count,
      "Stock portfolio should have #{RACE_COUNT} snapshots"

    # Should have dividend transactions (driver 0 finishes top consistently)
    dividend_txs = stock_portfolio.transactions.where(kind: "dividend")
    assert dividend_txs.any?, "Should have earned dividends from top-finishing driver"

    # Should have borrow fee transactions
    borrow_txs = stock_portfolio.transactions.where(kind: "borrow_fee")
    assert borrow_txs.any?, "Should have borrow fee charges for short position"

    # Leaderboard should work
    board = Fantasy::Leaderboard.new(season: @season).call
    assert board.any?, "Leaderboard should have entries"
    assert_equal portfolio, board.first[:portfolio]

    # Check achievements
    earned = Fantasy::CheckAchievements.new(portfolio: portfolio, race: @races.last).call
    # early_adopter should be earned (portfolio created before first race)
    keys = earned.compact.map(&:key)
    assert_includes keys, "early_adopter"

    # Sell shares
    sell_race = @races.last
    sell_race.update_columns(date: 1.week.from_now.to_date)

    long_holding = stock_portfolio.active_longs.first
    if long_holding
      sell_result = Fantasy::Stock::SellShares.new(
        portfolio: stock_portfolio, driver: long_holding.driver, quantity: 1, race: sell_race
      ).call
      assert sell_result[:success], "Should sell 1 share: #{sell_result[:error]}"
    end

    # Close short
    short_holding = stock_portfolio.active_shorts.first
    if short_holding
      close_result = Fantasy::Stock::CloseShort.new(
        portfolio: stock_portfolio, driver: short_holding.driver, quantity: short_holding.quantity, race: sell_race
      ).call
      assert close_result[:success], "Should close short: #{close_result[:error]}"
    end
    sell_race.update_columns(date: Date.new(2099, 3, 1) + (9 * 14).days)

    stock_portfolio.reload
    assert_equal 0, stock_portfolio.active_shorts.count, "All shorts should be closed"

    # Check stock achievements
    stock_earned = Fantasy::Stock::CheckAchievements.new(portfolio: stock_portfolio).call
    stock_keys = stock_earned.compact.map(&:key)
    assert_includes stock_keys, "first_stock_trade"
    assert_includes stock_keys, "first_long"
    assert_includes stock_keys, "first_short"
  end
end
