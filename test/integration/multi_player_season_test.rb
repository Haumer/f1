require "test_helper"

# Multi-player season simulation: 4 users with distinct strategies compete
# across both fantasy roster and stock market systems over a 12-race season
# with 8 drivers. Races are processed one-by-one: trade, then race, then Elo
# updates, then snapshot — so portfolio values genuinely track Elo movement.
#
# Strategies:
#   Alice  "Buy & Hold"     — buys the best drivers before race 1, never sells
#   Bob    "Active Trader"  — swaps drivers mid-season chasing breakout form
#   Carol  "Value Hunter"   — buys cheap backmarker drivers hoping they improve
#   Dave   "Stock Shark"    — stock-only: longs winners, shorts losers, mid-season pivot
class MultiPlayerSeasonTest < ActiveSupport::TestCase
  RACE_COUNT = 12
  DRIVER_COUNT = 8

  setup do
    @season = Season.create!(year: 2098)
    @circuit = circuits(:bahrain)

    @drivers = DRIVER_COUNT.times.map do |i|
      Driver.create!(
        driver_ref: "mp_driver_#{i}",
        forename: %w[Max Lando Charles Oscar Carlos Lewis George Yuki][i],
        surname: %w[Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel][i],
        code: "M#{i}X", number: 70 + i, nationality: "Test", active: true,
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
        year: 2098, round: i + 1,
        date: Date.new(2098, 3, 1) + (i * 14).days,
        time: "15:00:00", circuit: @circuit, season: @season,
        season_end: i == RACE_COUNT - 1
      )
    end

    @finished = statuses(:finished)

    @alice = create_user("alice")
    @bob   = create_user("bob")
    @carol = create_user("carol")
    @dave  = create_user("dave")

    @finishing_orders = generate_finishing_orders
  end

  test "multi-player season with different strategies" do
    # Create all portfolios BEFORE any racing (drivers all at 2000 Elo)
    alice_p  = create_portfolio(@alice)
    bob_p    = create_portfolio(@bob)
    carol_p  = create_portfolio(@carol)
    alice_sp = create_stock_portfolio(@alice)
    bob_sp   = create_stock_portfolio(@bob)
    dave_sp  = create_stock_portfolio(@dave)

    starting_capital = alice_p.starting_capital
    assert starting_capital > 0

    # ─── Pre-season trades (before race 1) ───
    pre_race_window(@races[0])
    # Alice: buy & hold top 2 (drivers 0,1) — at 2000 Elo each
    buy_driver!(alice_p, @drivers[0], @races[0])
    buy_driver!(alice_p, @drivers[1], @races[0])
    buy_shares!(alice_sp, @drivers[0], 3, @races[0])

    # Bob: buy midfield (drivers 2,4)
    buy_driver!(bob_p, @drivers[2], @races[0])
    buy_driver!(bob_p, @drivers[4], @races[0])
    buy_shares!(bob_sp, @drivers[1], 2, @races[0])

    # Carol: buy backmarkers (drivers 6,7)
    buy_driver!(carol_p, @drivers[6], @races[0])
    buy_driver!(carol_p, @drivers[7], @races[0])

    # Dave: stock only — long driver 0, short driver 7
    buy_shares!(dave_sp, @drivers[0], 3, @races[0])
    buy_shares!(dave_sp, @drivers[1], 2, @races[0])
    open_short!(dave_sp, @drivers[7], 2, @races[0])
    close_race_window(@races[0], 0)

    # ─── Race-by-race: run race → update Elo → snapshot → settle ───
    cumulative_points = Hash.new(0.0)

    RACE_COUNT.times do |idx|
      race = @races[idx]
      run_race(race, @finishing_orders[idx], cumulative_points)

      # Mid-season trades (after race 5, before race 6)
      if idx == 5
        execute_mid_season_trades(bob_p, bob_sp, dave_sp)
      end

      # Snapshot roster portfolios and settle stock market
      Fantasy::SnapshotPortfolios.new(race: race).call
      Fantasy::Stock::SettleRace.new(race: race).call
    end

    # ─── Reload all ───
    [alice_p, bob_p, carol_p].each(&:reload)
    [alice_sp, bob_sp, dave_sp].each(&:reload)
    @drivers.each(&:reload)

    # ─── Verify Elo separation ───
    verify_elo_separation

    # ─── Verify portfolio values diverged ───
    verify_roster_outcomes(alice_p, bob_p, carol_p, starting_capital)

    # ─── Verify stock market outcomes ───
    verify_stock_outcomes(alice_sp, bob_sp, dave_sp)

    # ─── Verify leaderboard ───
    verify_leaderboard(alice_p, bob_p, carol_p)

    # ─── Verify snapshots ───
    verify_snapshots([alice_p, bob_p, carol_p], [alice_sp, bob_sp, dave_sp])

    # ─── Verify achievements ───
    verify_achievements(alice_p, bob_p, carol_p, alice_sp, bob_sp, dave_sp)

    # ─── Verify transaction histories ───
    verify_transactions(alice_p, bob_p, carol_p, dave_sp)
  end

  private

  # ─── User/portfolio helpers ───

  def create_user(name)
    User.create!(email: "#{name}@example.com", password: "password123",
                 username: name, terms_accepted: "1")
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

  # ─── Trade helpers ───

  def pre_race_window(race)
    race.update_columns(date: 1.week.from_now.to_date)
  end

  def close_race_window(race, idx)
    race.update_columns(date: Date.new(2098, 3, 1) + (idx * 14).days)
  end

  def buy_driver!(portfolio, driver, race)
    r = Fantasy::BuyDriver.new(portfolio: portfolio, driver: driver, race: race).call
    assert r[:success], "#{portfolio.user.username} buy #{driver.surname} failed: #{r[:error]}"
  end

  def sell_driver!(portfolio, driver, race)
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

  # ─── Season engine ───

  # Tier 1: drivers 0,1 dominate first half; driver 3 breaks out second half
  def generate_finishing_orders
    RACE_COUNT.times.map do |r|
      rng = Random.new(r * 77)
      if r < 6
        front = [@drivers[0], @drivers[1]].shuffle(random: rng)
        mid   = [@drivers[2], @drivers[3], @drivers[4]].shuffle(random: rng)
        back  = [@drivers[5], @drivers[6], @drivers[7]].shuffle(random: rng)
      else
        front = [@drivers[0], @drivers[3]].shuffle(random: rng)
        mid   = [@drivers[1], @drivers[2], @drivers[4]].shuffle(random: rng)
        back  = [@drivers[5], @drivers[6], @drivers[7]].shuffle(random: rng)
      end
      front + mid + back
    end
  end

  def run_race(race, finishing_order, cumulative_points)
    points_table = [25, 18, 15, 12, 10, 8, 6, 4]

    finishing_order.each_with_index do |driver, pos|
      RaceResult.create!(
        race: race, driver: driver,
        constructor: driver.season_drivers.find_by(season: @season).constructor,
        grid: pos + 1, position: pos + 1, position_order: pos + 1,
        points: points_table[pos] || 0, laps: 57, status: @finished
      )
    end

    EloRatingV2.process_race(race)

    finishing_order.each_with_index { |d, pos| cumulative_points[d.id] += points_table[pos] || 0 }
    sorted = cumulative_points.sort_by { |_, pts| -pts }
    sorted.each_with_index do |(did, pts), rank|
      DriverStanding.create!(
        race: race, driver_id: did, points: pts,
        position: rank + 1, wins: finishing_order[0].id == did ? 1 : 0,
        season_end: race.season_end?
      )
    end
  end

  def execute_mid_season_trades(bob_p, bob_sp, dave_sp)
    pre_race_window(@races[6])

    # Bob: sell driver 4 (fading midfielder), buy driver 3 (breakout)
    sell_driver!(bob_p, @drivers[4], @races[6])
    buy_driver!(bob_p, @drivers[3], @races[6])

    # Bob stock: sell driver 1, buy driver 3
    Fantasy::Stock::SellShares.new(
      portfolio: bob_sp, driver: @drivers[1], quantity: 2, race: @races[6]
    ).call
    buy_shares!(bob_sp, @drivers[3], 2, @races[6])

    # Dave: pivot — sell some driver 1 shares, add driver 3 longs
    Fantasy::Stock::SellShares.new(
      portfolio: dave_sp, driver: @drivers[1], quantity: 1, race: @races[6]
    ).call
    buy_shares!(dave_sp, @drivers[3], 2, @races[6])

    close_race_window(@races[6], 6)
  end

  # ─── Validations ───

  def verify_elo_separation
    @drivers.each(&:reload)
    elos = @drivers.map(&:elo_v2)

    # Elo should separate meaningfully
    spread = elos.max - elos.min
    assert spread > 100, "Expected Elo spread > 100 after #{RACE_COUNT} races, got #{spread.round(1)}"

    # Dominant driver (0) should be highest
    assert @drivers[0].elo_v2 > @drivers[7].elo_v2,
      "Driver 0 (#{@drivers[0].elo_v2.round(1)}) should have higher Elo than driver 7 (#{@drivers[7].elo_v2.round(1)})"

    # Breakout driver (3) should have gained significantly from their starting 2000
    assert @drivers[3].elo_v2 > EloRatingV2::STARTING_ELO + 50,
      "Breakout driver 3 should be well above 2000 (at #{@drivers[3].elo_v2.round(1)})"

    # Backmarkers should have lost Elo
    [@drivers[6], @drivers[7]].each do |d|
      assert d.elo_v2 < EloRatingV2::STARTING_ELO,
        "Backmarker #{d.surname} should be below 2000 (at #{d.elo_v2.round(1)})"
    end
  end

  def verify_roster_outcomes(alice_p, bob_p, carol_p, starting_capital)
    alice_val = alice_p.portfolio_value
    bob_val   = bob_p.portfolio_value
    carol_val = carol_p.portfolio_value

    # Alice (frontrunners) should have profited — her drivers gained Elo
    assert alice_p.profit_loss > 0,
      "Alice (buy & hold top drivers) should be profitable (P&L: #{alice_p.profit_loss.round(1)}, value: #{alice_val.round(1)})"

    # Carol (backmarkers) should have lost — her drivers lost Elo
    assert carol_p.profit_loss < 0,
      "Carol (value hunter backmarkers) should be unprofitable (P&L: #{carol_p.profit_loss.round(1)}, value: #{carol_val.round(1)})"

    # Alice should beat Carol
    assert alice_val > carol_val,
      "Alice (#{alice_val.round(1)}) should have higher value than Carol (#{carol_val.round(1)})"

    # All portfolios should have different values (different strategies)
    values = [alice_val, bob_val, carol_val].map { |v| v.round(2) }
    assert_equal 3, values.uniq.size,
      "Three strategies should produce different values: Alice=#{alice_val.round(1)}, Bob=#{bob_val.round(1)}, Carol=#{carol_val.round(1)}"
  end

  def verify_stock_outcomes(alice_sp, bob_sp, dave_sp)
    [alice_sp, bob_sp, dave_sp].each do |sp|
      assert sp.portfolio_value > 0,
        "#{sp.user.username} stock portfolio value should be positive"
    end

    # Dave should have earned dividends (holds winning drivers)
    assert dave_sp.transactions.where(kind: "dividend").exists?,
      "Dave should have dividend transactions"

    # Dave should have borrow fees (he shorted driver 7)
    assert dave_sp.transactions.where(kind: "borrow_fee").exists?,
      "Dave should have borrow fee transactions"

    # Stock portfolio values should differ
    values = [alice_sp, bob_sp, dave_sp].map { |sp| sp.portfolio_value.round(2) }
    assert values.uniq.size >= 2,
      "Stock portfolio values should differ: #{values}"
  end

  def verify_leaderboard(alice_p, bob_p, carol_p)
    board = Fantasy::Leaderboard.new(season: @season).call
    assert_equal 3, board.size

    # Sorted by net P&L descending
    nets = board.map { |e| e[:net] }
    assert_equal nets.sort.reverse, nets, "Leaderboard should be sorted descending"

    # Alice should be ranked above Carol
    alice_rank = board.index { |e| e[:portfolio].user == @alice }
    carol_rank = board.index { |e| e[:portfolio].user == @carol }
    assert alice_rank < carol_rank,
      "Alice (rank #{alice_rank + 1}) should be above Carol (rank #{carol_rank + 1}) on leaderboard"
  end

  def verify_snapshots(roster_portfolios, stock_portfolios)
    roster_portfolios.each do |p|
      p.reload
      assert_equal RACE_COUNT, p.snapshots.count,
        "#{p.user.username} should have #{RACE_COUNT} roster snapshots"

      # Values should change over the season (Elo moves after each race)
      values = p.snapshots.order(:created_at).pluck(:value)
      assert values.uniq.size > 1,
        "#{p.user.username} snapshot values should vary across races"

      # All snapshots should have ranks
      assert_equal 0, p.snapshots.where(rank: nil).count,
        "#{p.user.username} should have ranks on all snapshots"
    end

    stock_portfolios.each do |sp|
      sp.reload
      assert_equal RACE_COUNT, sp.snapshots.count,
        "#{sp.user.username} should have #{RACE_COUNT} stock snapshots"
    end

    # Per-race roster ranks should be [1,2,3] — unique, no gaps
    @races.each do |race|
      ranks = FantasySnapshot.where(race: race).pluck(:rank).compact.sort
      assert_equal [1, 2, 3], ranks,
        "Race #{race.round} roster ranks should be [1,2,3], got #{ranks}"
    end
  end

  def verify_achievements(alice_p, bob_p, carol_p, alice_sp, bob_sp, dave_sp)
    [alice_p, bob_p, carol_p].each do |p|
      Fantasy::CheckAchievements.new(portfolio: p, race: @races.last).call
    end
    [alice_sp, bob_sp, dave_sp].each do |sp|
      Fantasy::Stock::CheckAchievements.new(portfolio: sp, race: @races.last).call
    end

    # All roster players should have first_trade
    [alice_p, bob_p, carol_p].each do |p|
      assert p.has_achievement?(:first_trade),
        "#{p.user.username} should have first_trade"
    end

    # Alice has the dominant driver — should have driver_won and driver_podium
    assert alice_p.has_achievement?(:driver_won),
      "Alice should have driver_won (holds dominant driver)"
    assert alice_p.has_achievement?(:driver_podium),
      "Alice should have driver_podium"

    # Alice should be profitable → first_profit
    assert alice_p.has_achievement?(:first_profit),
      "Alice should have first_profit (she's profitable)"

    # Bob traded: 2 buys + 1 sell + 1 buy = 4 trade transactions
    bob_trades = bob_p.transactions.where(kind: %w[buy sell]).count
    assert bob_trades >= 3, "Bob should have at least 3 trades (has #{bob_trades})"

    # Stock achievements
    [alice_sp, bob_sp, dave_sp].each do |sp|
      assert sp.has_achievement?(:first_stock_trade),
        "#{sp.user.username} should have first_stock_trade"
      assert sp.has_achievement?(:first_long),
        "#{sp.user.username} should have first_long"
    end

    assert dave_sp.has_achievement?(:first_short),
      "Dave should have first_short"
  end

  def verify_transactions(alice_p, bob_p, carol_p, dave_sp)
    # Alice: 2 buys, 0 sells (buy & hold)
    assert_equal 2, alice_p.transactions.where(kind: "buy").count
    assert_equal 0, alice_p.transactions.where(kind: "sell").count

    # Bob: 3 buys (2 initial + 1 breakout), 1 sell
    assert_equal 3, bob_p.transactions.where(kind: "buy").count
    assert_equal 1, bob_p.transactions.where(kind: "sell").count

    # Carol: 2 buys, 0 sells (passive value holder)
    assert_equal 2, carol_p.transactions.where(kind: "buy").count
    assert_equal 0, carol_p.transactions.where(kind: "sell").count

    # Dave: stock-only with buys, dividends, borrow fees
    assert dave_sp.transactions.where(kind: "buy").count >= 3
    assert dave_sp.transactions.where(kind: "dividend").count >= 1
    assert dave_sp.transactions.where(kind: "borrow_fee").count >= 1
  end
end
