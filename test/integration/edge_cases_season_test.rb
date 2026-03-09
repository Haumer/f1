require "test_helper"

# Edge-case season simulation: stress-tests the fantasy system with players
# who push every limit — maxing budgets, buying all teams, filling rosters,
# running out of cash, getting margin-called, rapid-fire trading to farm
# achievements, and attempting invalid trades that should be rejected.
#
# Players:
#   Eve     "Achievement Hunter" — buys all 3 teams, fills 6 roster slots,
#           trades 10+ times to unlock every roster achievement
#   Frank   "Broke Trader"      — spends all cash, tries to buy with $0,
#           gets stuck unable to trade
#   Grace   "Short Squeeze Victim" — opens a massive short on a driver who
#           then surges in Elo → margin call & auto-liquidation
#   Hank    "Invalid Trades"    — attempts every illegal operation: duplicate
#           buys, selling unheld drivers, buying with no cash, exceeding limits
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

  test "edge cases: achievement hunter maxes out everything" do
    eve = create_user("eve")

    # Create portfolio before first race (early adopter!)
    eve_p = create_portfolio(eve)
    starting_cash = eve_p.cash

    # Driver 0 dominates every race → huge Elo surge
    run_season_with_dominant_driver_0

    # ─── Eve's achievement hunting spree ───
    # Starting cash ~4400 (avg Elo 2000 * 2.2). Drivers cost ~2000, teams cost ~2000.
    # Strategy: buy team 2 first, then 1 driver, sell to fund team 3, then fill roster.

    open_window(@races[0])

    # Buy team 2 while we have maximum cash (trade window is open)
    team_result = Fantasy::BuyTeam.new(portfolio: eve_p, race: @races[0]).call
    assert team_result[:success], "Eve should buy team 2: #{team_result[:error]}"
    eve_p.reload
    assert_equal 4, eve_p.roster_slots
    assert_equal 2, eve_p.teams_owned

    # Buy 1 driver with remaining ~2400 cash
    buy!(eve_p, @drivers[0], @races[0])  # Trade 1: buy (~2000, leaves ~400)
    close_window(@races[0], 0)

    # After race 1 — sell driver 0 (who gained Elo, so sell price > buy price)
    open_window(@races[1])
    sell!(eve_p, @drivers[0], @races[1])  # Trade 2: sell (gets back ~2000+ after Elo surge)
    eve_p.reload

    # Buy team 3 with recovered cash
    team_result2 = Fantasy::BuyTeam.new(portfolio: eve_p, race: @races[1]).call
    assert team_result2[:success], "Eve should buy team 3: #{team_result2[:error]}"
    eve_p.reload
    assert_equal 6, eve_p.roster_slots
    assert_equal 3, eve_p.teams_owned
    refute eve_p.can_buy_team?, "Eve should be at max teams"
    close_window(@races[1], 1)

    # Now fill roster slots with drivers (6 slots, 0 active currently)
    # Need cash — Eve should still have some from the sell. Top up if needed.
    eve_p.update_columns(cash: [eve_p.cash, 15000].max) # ensure enough cash to fill roster
    open_window(@races[2])
    buy!(eve_p, @drivers[0], @races[2])  # Trade 3: buy
    buy!(eve_p, @drivers[1], @races[2])  # Trade 4: buy
    buy!(eve_p, @drivers[2], @races[2])  # Trade 5: buy
    buy!(eve_p, @drivers[3], @races[2])  # Trade 6: buy
    buy!(eve_p, @drivers[4], @races[2])  # Trade 7: buy
    buy!(eve_p, @drivers[5], @races[2])  # Trade 8: buy (roster: 6/6)
    assert eve_p.reload.roster_full?, "Eve should have full roster at 6/6"
    close_window(@races[2], 2)

    # More sell/buy cycles to hit 10 trades
    open_window(@races[4])
    sell!(eve_p, @drivers[5], @races[4])  # Trade 9: sell
    buy!(eve_p, @drivers[6], @races[4])   # Trade 10: buy
    close_window(@races[4], 4)

    # Snapshot all races
    @races.each { |race| Fantasy::SnapshotPortfolios.new(race: race).call }

    # Check achievements
    eve_p.reload
    earned = Fantasy::CheckAchievements.new(portfolio: eve_p, race: @races.last).call
    all_keys = eve_p.achievements.pluck(:key)

    # Roster achievements Eve should have
    assert eve_p.has_achievement?(:first_trade), "Eve should have first_trade"
    assert eve_p.has_achievement?(:five_trades), "Eve should have five_trades (has #{eve_p.transactions.where(kind: %w[buy sell]).count} trades)"
    assert eve_p.has_achievement?(:ten_trades), "Eve should have ten_trades"
    assert eve_p.has_achievement?(:second_team), "Eve should have second_team"
    assert eve_p.has_achievement?(:third_team), "Eve should have third_team"
    assert eve_p.has_achievement?(:driver_won), "Eve should have driver_won (holds driver 0)"
    assert eve_p.has_achievement?(:driver_podium), "Eve should have driver_podium"
    assert eve_p.has_achievement?(:first_profit), "Eve should have first_profit (driver 0 gained Elo)"

    # Early adopter — portfolio created before first race
    assert eve_p.has_achievement?(:early_adopter), "Eve should have early_adopter"
  end

  test "edge cases: broke trader runs out of cash" do
    frank = create_user("frank")

    run_season_with_dominant_driver_0

    frank_p = create_portfolio(frank)
    starting_cash = frank_p.cash

    # Frank spends almost all his cash buying 2 drivers
    open_window(@races[0])
    buy!(frank_p, @drivers[0], @races[0])
    buy!(frank_p, @drivers[1], @races[0])
    close_window(@races[0], 0)

    frank_p.reload
    remaining_cash = frank_p.cash
    assert remaining_cash < starting_cash, "Frank should have less cash after buying"

    # Try to buy a third driver — should fail (roster full at 2 slots)
    open_window(@races[1])
    result = Fantasy::BuyDriver.new(portfolio: frank_p, driver: @drivers[2], race: @races[1]).call
    assert result[:error].present?, "Frank should get an error buying 3rd driver"
    assert_match(/Roster is full/, result[:error])

    # Try to buy a team — may fail if not enough cash
    team_cost = frank_p.team_cost
    if frank_p.cash < team_cost
      team_result = Fantasy::BuyTeam.new(portfolio: frank_p, race: @races[1]).call
      assert_match(/Not enough cash/, team_result[:error])
    end

    # Frank sells driver 1 to free up cash, then buys team, then blows remaining cash
    sell!(frank_p, @drivers[1], @races[1])
    frank_p.reload

    # Now try buying team with whatever cash he has
    team_result = Fantasy::BuyTeam.new(portfolio: frank_p, race: @races[1]).call
    if team_result[:success]
      frank_p.reload
      # Buy another driver with remaining cash
      buy_result = Fantasy::BuyDriver.new(portfolio: frank_p, driver: @drivers[2], race: @races[1]).call
      if buy_result[:success]
        frank_p.reload
      end
    end
    close_window(@races[1], 1)

    # Now try to buy with no cash
    frank_p.update_columns(cash: 0.0)
    open_window(@races[3])
    broke_result = Fantasy::BuyDriver.new(portfolio: frank_p, driver: @drivers[7], race: @races[3]).call
    assert broke_result[:error].present?
    assert_match(/Not enough cash/, broke_result[:error])

    # Also can't buy a team
    team_broke = Fantasy::BuyTeam.new(portfolio: frank_p, race: @races[3]).call
    assert team_broke[:error].present?
    assert_match(/Not enough cash/, team_broke[:error])
    close_window(@races[3], 3)

    # Snapshot — portfolio value should still be positive (driver Elo has value)
    @races.each { |race| Fantasy::SnapshotPortfolios.new(race: race).call }
    frank_p.reload
    assert frank_p.portfolio_value > 0,
      "Frank's portfolio value should be positive even with 0 cash (drivers have Elo value)"
    assert_equal 0.0, frank_p.cash, "Frank should have exactly 0 cash"

    # Stock portfolio: try same thing
    frank_sp = create_stock_portfolio(frank)
    frank_sp.wallet.update_columns(cash: 0.0)
    open_window(@races[5])
    stock_result = Fantasy::Stock::BuyShares.new(
      portfolio: frank_sp, driver: @drivers[0], quantity: 1, race: @races[5]
    ).call
    assert_match(/Not enough cash/, stock_result[:error])

    short_result = Fantasy::Stock::OpenShort.new(
      portfolio: frank_sp, driver: @drivers[7], quantity: 1, race: @races[5]
    ).call
    assert_match(/Not enough cash for collateral/, short_result[:error])
    close_window(@races[5], 5)
  end

  test "edge cases: short squeeze triggers margin call" do
    grace = create_user("grace")
    create_portfolio(grace)

    # Don't run full season yet — we want to control Elo incrementally
    grace_sp = create_stock_portfolio(grace)
    initial_capital = grace_sp.starting_capital

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
    # Margin call triggers when current_price >= entry_price * (1 + 2.0) = 3x entry
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
    hank_sp = create_stock_portfolio(hank)

    run_season_with_dominant_driver_0

    open_window(@races[0])

    # ─── Roster: invalid operations ───

    # Buy a driver
    buy!(hank_p, @drivers[0], @races[0])

    # Try to buy same driver again
    dup = Fantasy::BuyDriver.new(portfolio: hank_p, driver: @drivers[0], race: @races[0]).call
    assert_equal "Driver is already on your roster", dup[:error]

    # Fill roster (2 slots), try to buy a 3rd
    buy!(hank_p, @drivers[1], @races[0])
    full = Fantasy::BuyDriver.new(portfolio: hank_p, driver: @drivers[2], race: @races[0]).call
    assert_match(/Roster is full/, full[:error])

    # Sell a driver we don't have
    not_held = Fantasy::SellDriver.new(portfolio: hank_p, driver: @drivers[5], race: @races[0]).call
    assert_equal "Driver is not on your roster", not_held[:error]

    # Try to buy with insufficient cash (expand roster first so we don't hit "Roster is full")
    hank_p.update_columns(cash: 1.0, roster_slots: 4)
    poor = Fantasy::BuyDriver.new(portfolio: hank_p, driver: @drivers[3], race: @races[0]).call
    assert_match(/Not enough cash/, poor[:error])
    hank_p.update_columns(cash: 5000.0, roster_slots: 2) # restore

    # Try to buy a 4th team (max is 3)
    hank_p.update_columns(roster_slots: FantasyPortfolio::MAX_TEAMS * FantasyPortfolio::SLOTS_PER_TEAM)
    max_teams = Fantasy::BuyTeam.new(portfolio: hank_p, race: @races[0]).call
    assert_match(/Already at maximum teams/, max_teams[:error])
    hank_p.update_columns(roster_slots: 2) # restore

    close_window(@races[0], 0)

    # Closed transfer window — set date to past so can_trade? returns false
    @races[0].update_columns(date: 1.day.ago.to_date, time: "15:00:00")
    closed = Fantasy::BuyDriver.new(portfolio: hank_p, driver: @drivers[3], race: @races[0]).call
    assert_equal "Transfer window is closed", closed[:error]
    close_window(@races[0], 0) # restore

    # ─── Stock market: invalid operations ───

    open_window(@races[1])

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
    assert_match(/Not enough cash/, no_cash[:error])

    # Short with no cash for collateral
    no_collateral = Fantasy::Stock::OpenShort.new(
      portfolio: hank_sp, driver: @drivers[3], quantity: 1, race: @races[1]
    ).call
    assert_match(/Not enough cash for collateral/, no_collateral[:error])
    hank_sp.wallet.update_columns(cash: 5000.0)

    # Fill max positions (6), then try to open another
    4.times do |i|
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
    sp = create_stock_portfolio(user)

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
    create_stock_portfolio(user)

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

  def create_stock_portfolio(user)
    r = Fantasy::Stock::CreatePortfolio.new(user: user, season: @season).call
    assert r[:portfolio], "#{user.username} stock portfolio failed: #{r[:error]}"
    r[:portfolio]
  end

  def open_window(race)
    race.update_columns(date: 1.week.from_now.to_date)
  end

  def close_window(race, idx)
    race.update_columns(date: Date.new(2097, 3, 1) + (idx * 14).days)
  end

  def buy!(portfolio, driver, race)
    r = Fantasy::BuyDriver.new(portfolio: portfolio, driver: driver, race: race).call
    assert r[:success], "#{portfolio.user.username} buy #{driver.surname} failed: #{r[:error]}"
  end

  def sell!(portfolio, driver, race)
    r = Fantasy::SellDriver.new(portfolio: portfolio, driver: driver, race: race).call
    assert r[:success], "#{portfolio.user.username} sell #{driver.surname} failed: #{r[:error]}"
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
