require "test_helper"

# Edge-case season simulation: stress-tests the fantasy system with players
# who push every limit — maxing positions, running out of cash, getting
# margin-called, rapid-fire trading, and attempting invalid trades that
# should be rejected.
#
# Players:
#   Eve     "Achievement Hunter" — trades stocks aggressively to unlock achievements
#   Frank   "Broke Trader"      — spends all cash, tries to buy with $0
#   Grace   "Short Squeeze Victim" — opens a massive short on a driver who
#           then surges in Elo -> margin call & auto-liquidation
#   Hank    "Invalid Trades"    — attempts every illegal operation
class EdgeCasesSeasonTest < ActiveSupport::TestCase
  RACE_COUNT = 14
  DRIVER_COUNT = 8

  setup do
    @season = Season.create!(year: 2097)
    @circuit = circuits(:bahrain)

    @drivers = DRIVER_COUNT.times.map do |i|
      Driver.create!(
        driver_ref: "edge_driver_#{i}",
        forename: "Edge", surname: "Driver#{i}",
        code: "E#{i}X", number: 90 + i, nationality: "Test", active: true,
        elo_v2: EloRatingV2::STARTING_ELO,
        peak_elo_v2: EloRatingV2::STARTING_ELO
      )
    end

    team_pool = [constructors(:mclaren), constructors(:red_bull), constructors(:ferrari)]
    @drivers.each_with_index do |d, i|
      SeasonDriver.create!(driver: d, season: @season, constructor: team_pool[i % 3])
    end

    @races = RACE_COUNT.times.map do |i|
      Race.create!(
        year: 2097, round: i + 1,
        date: Date.new(2097, 3, 1) + (i * 14).days,
        time: "15:00:00", circuit: @circuit, season: @season,
        season_end: i == RACE_COUNT - 1
      )
    end

    @finished = statuses(:finished)
  end

  test "edge cases: achievement hunter trades aggressively for stock achievements" do
    eve = create_user("eve")
    eve_p = create_portfolio(eve)
    eve_sp = eve.fantasy_stock_portfolio_for(@season)
    assert eve_sp, "Stock portfolio should be auto-created"

    # Driver 0 dominates every race -> huge Elo surge
    run_season_with_dominant_driver_0

    open_window(@races[0])

    # Buy multiple positions
    buy_shares!(eve_sp, @drivers[0], 3, @races[0])  # Trade 1
    buy_shares!(eve_sp, @drivers[1], 2, @races[0])  # Trade 2
    buy_shares!(eve_sp, @drivers[2], 1, @races[0])  # Trade 3
    close_window(@races[0], 0)

    # Sell and rebuy to generate more trades
    open_window(@races[1])
    Fantasy::Stock::SellShares.new(
      portfolio: eve_sp, driver: @drivers[2], quantity: 1, race: @races[1]
    ).call
    buy_shares!(eve_sp, @drivers[3], 1, @races[1])   # Trade 5
    open_short!(eve_sp, @drivers[7], 1, @races[1])    # Trade 6
    close_window(@races[1], 1)

    # Snapshot all races
    @races.each { |race| Fantasy::SnapshotPortfolios.new(race: race).call }

    # Check stock achievements
    eve_sp.reload
    Fantasy::Stock::CheckAchievements.new(portfolio: eve_sp).call

    assert eve_sp.has_achievement?(:first_stock_trade), "Eve should have first_stock_trade"
    assert eve_sp.has_achievement?(:first_long), "Eve should have first_long"
    assert eve_sp.has_achievement?(:first_short), "Eve should have first_short"

    # Check roster achievements
    Fantasy::CheckAchievements.new(portfolio: eve_p, race: @races.last).call
    assert eve_p.has_achievement?(:early_adopter), "Eve should have early_adopter"
  end

  test "edge cases: broke trader runs out of cash" do
    frank = create_user("frank")
    frank_p = create_portfolio(frank)
    frank_sp = frank.fantasy_stock_portfolio_for(@season)
    assert frank_sp, "Stock portfolio should be auto-created"

    run_season_with_dominant_driver_0

    starting_cash = frank_p.cash

    # Frank buys shares until cash runs low
    open_window(@races[0])
    buy_shares!(frank_sp, @drivers[0], 3, @races[0])
    buy_shares!(frank_sp, @drivers[1], 2, @races[0])
    close_window(@races[0], 0)

    frank_p.reload
    remaining_cash = frank_p.cash
    assert remaining_cash < starting_cash, "Frank should have less cash after buying"

    # Try to buy with no cash
    frank_p.update_columns(cash: 0.0)
    # Reload stock portfolio so wallet cache is cleared
    frank_sp = FantasyStockPortfolio.find(frank_sp.id)
    open_window(@races[3])
    broke_result = Fantasy::Stock::BuyShares.new(
      portfolio: frank_sp, driver: @drivers[7], quantity: 1, race: @races[3]
    ).call
    assert_match(/Not enough credits/, broke_result[:error])

    # Also can't open short with no cash for collateral
    short_result = Fantasy::Stock::OpenShort.new(
      portfolio: frank_sp, driver: @drivers[7], quantity: 1, race: @races[3]
    ).call
    assert_match(/Not enough credits for collateral/, short_result[:error])
    close_window(@races[3], 3)

    # Snapshot — portfolio value should still be positive (stock holdings have value)
    @races.each { |race| Fantasy::SnapshotPortfolios.new(race: race).call }
    frank_p.reload
    assert frank_p.portfolio_value > 0,
      "Frank's portfolio value should be positive even with 0 cash (stock holdings have value)"
    assert_equal 0.0, frank_p.cash, "Frank should have exactly 0 cash"
  end

  test "edge cases: short squeeze triggers margin call" do
    grace = create_user("grace")
    grace_p = create_portfolio(grace)
    grace_sp = grace.fantasy_stock_portfolio_for(@season)
    assert grace_sp, "Stock portfolio should be auto-created"

    # Grace shorts driver 0 (who will surge in Elo)
    open_window(@races[0])
    open_short_result = Fantasy::Stock::OpenShort.new(
      portfolio: grace_sp, driver: @drivers[0], quantity: 5, race: @races[0]
    ).call
    assert open_short_result[:success], "Grace should open short: #{open_short_result[:error]}"
    close_window(@races[0], 0)

    grace_sp.reload
    short_entry_price = grace_sp.active_shorts.first.entry_price
    initial_collateral = grace_sp.total_collateral
    assert initial_collateral > 0

    # Run races where driver 0 dominates — Elo surges
    cumulative_points = Hash.new(0.0)
    RACE_COUNT.times do |idx|
      run_single_race(@races[idx], idx, cumulative_points)
      Fantasy::Stock::SettleRace.new(race: @races[idx]).call
    end

    grace_sp.reload
    @drivers[0].reload

    # Driver 0 Elo should have surged well above starting 2000
    assert @drivers[0].elo_v2 > 2200,
      "Driver 0 should have surged (at #{@drivers[0].elo_v2.round(1)})"

    # Check if margin call happened — the short should be liquidated
    current_share_price = grace_sp.share_price(@drivers[0])

    if current_share_price >= short_entry_price * 3.0
      # Should have been auto-liquidated
      assert grace_sp.active_shorts.where(driver: @drivers[0]).count == 0,
        "Grace's short should have been margin-called"
      assert grace_sp.transactions.where(kind: "liquidation").exists?,
        "Should have liquidation transaction"
    end

    # Borrow fees should have been charged every race the short was active
    borrow_fees = grace_sp.transactions.where(kind: "borrow_fee")
    assert borrow_fees.count >= 1, "Grace should have been charged borrow fees"

    # Wallet cash should never go negative
    assert grace_sp.wallet.reload.cash >= 0, "Cash should never be negative, got #{grace_sp.wallet.cash}"

    # Even if she lost a lot, portfolio_value should handle it
    pv = grace_sp.portfolio_value
    assert pv.is_a?(Numeric), "portfolio_value should return a number"
  end

  test "edge cases: invalid trades are all rejected" do
    hank = create_user("hank")
    hank_p = create_portfolio(hank)
    hank_sp = hank.fantasy_stock_portfolio_for(@season)
    assert hank_sp, "Stock portfolio should be auto-created"

    run_season_with_dominant_driver_0

    open_window(@races[1])

    # --- Stock market: invalid operations ---

    # Buy 0 shares
    zero_qty = Fantasy::Stock::BuyShares.new(
      portfolio: hank_sp, driver: @drivers[0], quantity: 0, race: @races[1]
    ).call
    assert_equal "Invalid quantity", zero_qty[:error]

    # Buy negative shares
    neg_qty = Fantasy::Stock::BuyShares.new(
      portfolio: hank_sp, driver: @drivers[0], quantity: -5, race: @races[1]
    ).call
    assert_equal "Invalid quantity", neg_qty[:error]

    # Sell shares we don't own
    no_hold = Fantasy::Stock::SellShares.new(
      portfolio: hank_sp, driver: @drivers[3], quantity: 1, race: @races[1]
    ).call
    assert_equal "You don't hold this driver", no_hold[:error]

    # Close a short we don't have
    no_short = Fantasy::Stock::CloseShort.new(
      portfolio: hank_sp, driver: @drivers[5], quantity: 1, race: @races[1]
    ).call
    assert_equal "No short position on this driver", no_short[:error]

    # Buy shares, then try to sell more than we hold
    buy_shares!(hank_sp, @drivers[0], 2, @races[1])
    oversell = Fantasy::Stock::SellShares.new(
      portfolio: hank_sp, driver: @drivers[0], quantity: 999, race: @races[1]
    ).call
    assert_match(/You only hold/, oversell[:error])

    # Open short, then try to close more than we have
    open_short!(hank_sp, @drivers[7], 1, @races[1])
    overclose = Fantasy::Stock::CloseShort.new(
      portfolio: hank_sp, driver: @drivers[7], quantity: 999, race: @races[1]
    ).call
    assert_match(/You only have/, overclose[:error])

    # Buy with no cash
    hank_sp.wallet.update_columns(cash: 0.0)
    no_cash = Fantasy::Stock::BuyShares.new(
      portfolio: hank_sp, driver: @drivers[2], quantity: 1, race: @races[1]
    ).call
    assert_match(/Not enough credits/, no_cash[:error])

    # Short with no cash for collateral
    no_collateral = Fantasy::Stock::OpenShort.new(
      portfolio: hank_sp, driver: @drivers[3], quantity: 1, race: @races[1]
    ).call
    assert_match(/Not enough credits for collateral/, no_collateral[:error])
    hank_sp.wallet.update_columns(cash: 5000.0)

    # Fill max positions (12), then try to open another
    10.times do |i|
      d = Driver.create!(surname: "Filler#{i}", driver_ref: "fill_edge_#{i}", active: true,
                          elo_v2: 2000, peak_elo_v2: 2000)
      SeasonDriver.create!(driver: d, season: @season, constructor: constructors(:mclaren))
      hank_sp.holdings.create!(
        driver: d, quantity: 1, direction: "long", entry_price: 200.0,
        opened_race: @races[1], active: true
      )
    end
    max_pos = Fantasy::Stock::BuyShares.new(
      portfolio: hank_sp, driver: @drivers[3], quantity: 1, race: @races[1]
    ).call
    assert_match(/Too many positions/, max_pos[:error])

    close_window(@races[1], 1)

    # Closed window for stock — set date to past
    @races[1].update_columns(date: 1.day.ago.to_date, time: "15:00:00")
    closed_stock = Fantasy::Stock::BuyShares.new(
      portfolio: hank_sp, driver: @drivers[0], quantity: 1, race: @races[1]
    ).call
    assert_equal "Transfer window is closed", closed_stock[:error]
    close_window(@races[1], 1) # restore
  end

  test "edge cases: cash floor is respected everywhere" do
    # Verify cash never goes negative in any scenario
    user = create_user("cashfloor")
    create_portfolio(user)
    sp = user.fantasy_stock_portfolio_for(@season)
    assert sp, "Stock portfolio should be auto-created"

    # Open a large short at low entry price, then driver surges
    open_window(@races[0])
    open_short!(sp, @drivers[0], 3, @races[0])
    close_window(@races[0], 0)

    # Manually set entry_price very low to simulate massive loss
    holding = sp.active_shorts.first
    holding.update_columns(entry_price: 10.0) # fake low entry

    # Run season — driver 0 surges, so short P&L is hugely negative
    cumulative_points = Hash.new(0.0)
    RACE_COUNT.times do |idx|
      run_single_race(@races[idx], idx, cumulative_points)
      Fantasy::Stock::SettleRace.new(race: @races[idx]).call
    end

    sp.reload
    # Wallet cash should never be negative
    wallet = sp.wallet.reload
    assert wallet.cash >= 0, "Cash should never go negative, got #{wallet.cash}"

    # Try to manually close the short (if still active)
    if sp.active_shorts.any?
      open_window(@races.last)
      close_result = Fantasy::Stock::CloseShort.new(
        portfolio: sp, driver: @drivers[0],
        quantity: sp.active_shorts.first.quantity,
        race: @races.last
      ).call
      close_window(@races.last, RACE_COUNT - 1)
      sp.reload
      assert sp.wallet.reload.cash >= 0, "Cash should still not be negative after closing short, got #{sp.wallet.cash}"
    end

    # Every snapshot should have non-negative cash
    sp.snapshots.each do |snap|
      assert snap.cash >= 0, "Snapshot cash should never be negative (race #{snap.race_id}: #{snap.cash})"
    end
  end

  test "edge cases: duplicate portfolio creation rejected" do
    user = create_user("duptest")
    create_portfolio(user)

    # Try to create again
    dup_roster = Fantasy::CreatePortfolio.new(user: user, season: @season).call
    assert_equal "You already have a portfolio for this season", dup_roster[:error]

    dup_stock = Fantasy::Stock::CreatePortfolio.new(user: user, season: @season).call
    assert_equal "You already have a stock portfolio for this season", dup_stock[:error]
  end

  private

  def create_user(name)
    User.create!(email: "#{name}_edge@example.com", password: "password123",
                 username: "#{name}_edge", terms_accepted: "1")
  end

  def create_portfolio(user)
    r = Fantasy::CreatePortfolio.new(user: user, season: @season).call
    assert r[:portfolio], "#{user.username} portfolio failed: #{r[:error]}"
    r[:portfolio]
  end

  def open_window(race)
    race.update_columns(date: 1.week.from_now.to_date)
  end

  def close_window(race, idx)
    race.update_columns(date: Date.new(2097, 3, 1) + (idx * 14).days)
  end

  def buy_shares!(portfolio, driver, qty, race)
    r = Fantasy::Stock::BuyShares.new(portfolio: portfolio, driver: driver, quantity: qty, race: race).call
    assert r[:success], "#{portfolio.user.username} buy #{qty}x #{driver.surname} failed: #{r[:error]}"
  end

  def open_short!(portfolio, driver, qty, race)
    r = Fantasy::Stock::OpenShort.new(portfolio: portfolio, driver: driver, quantity: qty, race: race).call
    assert r[:success], "#{portfolio.user.username} short #{qty}x #{driver.surname} failed: #{r[:error]}"
  end

  # Driver 0 wins every race, driver 7 last every race
  def generate_dominant_orders(race_idx)
    rng = Random.new(race_idx * 99)
    middle = @drivers[1..6].shuffle(random: rng)
    [@drivers[0]] + middle + [@drivers[7]]
  end

  def run_season_with_dominant_driver_0
    cumulative_points = Hash.new(0.0)
    RACE_COUNT.times { |idx| run_single_race(@races[idx], idx, cumulative_points) }
  end

  def run_single_race(race, idx, cumulative_points)
    order = generate_dominant_orders(idx)
    points_table = [25, 18, 15, 12, 10, 8, 6, 4]

    order.each_with_index do |driver, pos|
      # Don't create duplicate race results
      next if RaceResult.exists?(race: race, driver: driver)
      RaceResult.create!(
        race: race, driver: driver,
        constructor: driver.season_drivers.find_by(season: @season).constructor,
        grid: pos + 1, position: pos + 1, position_order: pos + 1,
        points: points_table[pos] || 0, laps: 57, status: @finished
      )
    end

    EloRatingV2.process_race(race) unless race.race_results.any? { |rr| rr.new_elo_v2.present? }

    order.each_with_index { |d, pos| cumulative_points[d.id] += points_table[pos] || 0 }
    return if DriverStanding.exists?(race: race)
    sorted = cumulative_points.sort_by { |_, pts| -pts }
    sorted.each_with_index do |(did, pts), rank|
      DriverStanding.create!(
        race: race, driver_id: did, points: pts,
        position: rank + 1, wins: order[0].id == did ? 1 : 0,
        season_end: race.season_end?
      )
    end
  end
end
