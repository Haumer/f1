module Fantasy
  class ReplayTransactions
    def initialize(season:, dry_run: false, reprice: false)
      @season = season
      @dry_run = dry_run
      @reprice = reprice
      @results = []
    end

    def call
      full_replay if @reprice
      replay_cash
      @results
    end

    private

    def full_replay
      race = @season.races.order(:round).first
      raise "No race found for season #{@season.year}" unless race

      # Pre-R1 elo for each driver (the elo going INTO the race)
      pre_race_elos = RaceResult.where(race: race).pluck(:driver_id, :old_elo_v2).to_h
      puts "Pre-R1 elos loaded for #{pre_race_elos.size} drivers"

      # Load all drivers for name lookups
      drivers_by_id = Driver.where(id: pre_race_elos.keys).index_by(&:id)

      ActiveRecord::Base.transaction do
        # 1. Fix roster buy transactions and roster entries
        reprice_roster_buys(pre_race_elos, drivers_by_id)

        # 2. Reset net_demand to 0 for all season drivers
        SeasonDriver.where(season: @season).update_all(net_demand: 0)
        puts "Reset net_demand to 0"

        # Track demand as we replay
        demand = Hash.new(0)

        # 3. Replay stock trades in chronological order
        reprice_stock_trades(pre_race_elos, drivers_by_id, demand)

        # 4. Persist final demand values
        demand.each do |driver_id, net|
          SeasonDriver.where(season: @season, driver_id: driver_id).update_all(net_demand: net)
        end
        puts "Final demand persisted"

        # 5. Update stock holding entry prices and collateral
        reprice_holdings(pre_race_elos, drivers_by_id, demand)

        # 6. Recalculate borrow fees with new entry prices
        recalculate_borrow_fees(race, drivers_by_id)

        # 7. Delete and recreate stock price snapshot for this race
        StockPriceSnapshot.where(race: race).delete_all
        FantasyStockPortfolio.where(season: @season).includes(holdings: :driver).each do |sp|
          sp.holdings.select(&:active).each do |h|
            base = (drivers_by_id[h.driver_id]&.elo_v2 || EloRatingV2::STARTING_ELO) / FantasyStockPortfolio::PRICE_DIVISOR
            net = demand[h.driver_id]
            price = apply_demand(base, net)
            StockPriceSnapshot.find_or_create_by!(driver_id: h.driver_id, race: race) do |snap|
              snap.elo = drivers_by_id[h.driver_id]&.elo_v2
              snap.net_demand = net
              snap.price = price
            end
          end
        end
        puts "Stock price snapshots recreated"
      end
    end

    def reprice_roster_buys(pre_race_elos, drivers_by_id)
      roster_portfolios = FantasyPortfolio.where(season: @season)
      txns = FantasyTransaction.where(kind: "buy", fantasy_portfolio_id: roster_portfolios.select(:id)).includes(:driver)
      changes = 0

      txns.each do |txn|
        correct_elo = pre_race_elos[txn.driver_id] || EloRatingV2::STARTING_ELO
        correct_amount = -correct_elo
        next if (txn.amount - correct_amount).abs < 0.01

        name = drivers_by_id[txn.driver_id]&.fullname || txn.driver_id
        puts "  Roster buy #{name}: #{txn.amount.round(1)} -> #{correct_amount.round(1)}"
        txn.update_column(:amount, correct_amount)

        # Update roster entry's bought_at_elo
        FantasyRosterEntry.where(
          fantasy_portfolio_id: txn.fantasy_portfolio_id,
          driver_id: txn.driver_id, active: true
        ).update_all(bought_at_elo: correct_elo)

        changes += 1
      end
      puts "Repriced #{changes} roster buys"
    end

    def reprice_stock_trades(pre_race_elos, drivers_by_id, demand)
      stock_portfolios = FantasyStockPortfolio.where(season: @season)
      txns = FantasyStockTransaction.where(
        kind: %w[buy short_open],
        fantasy_stock_portfolio_id: stock_portfolios.select(:id)
      ).includes(:driver).order(:created_at)

      changes = 0
      txns.each do |txn|
        elo = pre_race_elos[txn.driver_id] || EloRatingV2::STARTING_ELO
        base = elo / FantasyStockPortfolio::PRICE_DIVISOR
        # Price includes demand from all trades BEFORE this one
        price = apply_demand(base, demand[txn.driver_id])
        name = drivers_by_id[txn.driver_id]&.fullname || txn.driver_id

        if txn.kind == "buy"
          correct_amount = -(price * txn.quantity)
          puts "  Stock buy #{txn.quantity}x #{name}: #{txn.amount.round(1)} -> #{correct_amount.round(1)} (demand=#{demand[txn.driver_id]})"
          txn.update_columns(amount: correct_amount, price: price)
          demand[txn.driver_id] += txn.quantity
        elsif txn.kind == "short_open"
          collateral = (price * txn.quantity * FantasyStockPortfolio::COLLATERAL_RATIO).round(1)
          puts "  Short #{txn.quantity}x #{name}: price #{txn.price.round(1)} -> #{price.round(1)} (demand=#{demand[txn.driver_id]})"
          txn.update_columns(
            price: price, amount: 0,
            note: "Shorted #{txn.quantity}x #{name} at #{price.round(1)} (#{collateral} collateral locked)"
          )
          demand[txn.driver_id] -= txn.quantity
        end

        changes += 1
      end
      puts "Repriced #{changes} stock trades"
    end

    def reprice_holdings(pre_race_elos, drivers_by_id, demand)
      stock_portfolios = FantasyStockPortfolio.where(season: @season)
      holdings = FantasyStockHolding.where(
        fantasy_stock_portfolio_id: stock_portfolios.select(:id), active: true
      ).includes(:driver, :fantasy_stock_portfolio)

      # Group trades by portfolio+driver to calculate correct avg entry price
      trades_by_key = FantasyStockTransaction.where(
        kind: %w[buy short_open],
        fantasy_stock_portfolio_id: stock_portfolios.select(:id)
      ).order(:created_at).group_by { |t| [t.fantasy_stock_portfolio_id, t.driver_id] }

      changes = 0
      holdings.each do |h|
        key = [h.fantasy_stock_portfolio_id, h.driver_id]
        txns = trades_by_key[key] || []
        next if txns.empty?

        # For holdings with multiple buys, calculate weighted avg entry price
        if txns.size == 1
          correct_price = txns.first.price
        else
          total_qty = txns.sum(&:quantity)
          total_cost = txns.sum { |t| t.price * t.quantity }
          correct_price = total_cost / total_qty
        end

        name = drivers_by_id[h.driver_id]&.fullname || h.driver_id
        next if (h.entry_price - correct_price).abs < 0.01

        puts "  Holding #{h.direction} #{h.quantity}x #{name}: entry #{h.entry_price.round(1)} -> #{correct_price.round(1)}"
        attrs = { entry_price: correct_price }
        if h.direction == "short"
          attrs[:collateral] = correct_price * h.quantity * FantasyStockPortfolio::COLLATERAL_RATIO
        end
        h.update_columns(attrs)
        changes += 1
      end
      puts "Updated #{changes} holdings"
    end

    def recalculate_borrow_fees(race, drivers_by_id)
      stock_portfolios = FantasyStockPortfolio.where(season: @season).includes(:holdings)
      fee_rate = Fantasy::Stock::SettleRace::BORROW_FEE_RATE

      changes = 0
      stock_portfolios.each do |sp|
        fee_txns = sp.transactions.where(kind: "borrow_fee", race: race)
        fee_txns.each do |txn|
          holding = sp.holdings.find { |h| h.driver_id == txn.driver_id && h.active }
          next unless holding

          fee_per_share = holding.entry_price * fee_rate
          correct_fee = -(fee_per_share * holding.quantity)
          next if (txn.amount - correct_fee).abs < 0.01

          name = drivers_by_id[txn.driver_id]&.fullname || txn.driver_id
          puts "  Borrow fee #{holding.quantity}x #{name}: #{txn.amount.round(2)} -> #{correct_fee.round(2)}"
          txn.update_columns(amount: correct_fee, price: fee_per_share)
          changes += 1
        end
      end
      puts "Recalculated #{changes} borrow fees"
    end

    def apply_demand(base, net_demand)
      base * Fantasy::Pricing.demand_multiplier(net_demand)
    end

    # Phase 2: replay cash from all transactions
    def replay_cash
      portfolios = FantasyPortfolio.where(season: @season)
                     .includes(:user, :transactions, roster_entries: :driver)

      portfolios.each do |portfolio|
        replay_portfolio(portfolio)
      end
    end

    def replay_portfolio(portfolio)
      sp = FantasyStockPortfolio.find_by(user_id: portfolio.user_id, season_id: @season.id)
      old_cash = portfolio.cash

      backfill_starting_capital(portfolio, sp)

      all_txns = portfolio.transactions.reload.order(:created_at).to_a
      if sp
        stock_txns = sp.transactions.reload.order(:created_at).to_a
        all_txns = (all_txns + stock_txns).sort_by(&:created_at)
      end

      cash = 0.0
      all_txns.each { |txn| cash += txn.amount }

      @results << {
        user: portfolio.user.username,
        old_cash: old_cash.round(2),
        new_cash: cash.round(2),
        diff: (cash - old_cash).round(2),
        txn_count: all_txns.size
      }

      unless @dry_run
        portfolio.update!(cash: cash)
        # Recompute collateral on active shorts with current prices
        if sp
          sp.active_shorts.includes(:driver).each do |h|
            correct = h.entry_price * h.quantity * FantasyStockPortfolio::COLLATERAL_RATIO
            h.update_column(:collateral, correct) if (h.collateral - correct).abs > 0.01
          end
        end
      end
    end

    def backfill_starting_capital(portfolio, stock_portfolio)
      unless portfolio.transactions.exists?(kind: "starting_capital")
        portfolio.transactions.create!(
          kind: "starting_capital",
          amount: portfolio.starting_capital,
          note: "Roster starting capital",
          created_at: portfolio.created_at
        )
      end

      if stock_portfolio
        has_stock_capital = portfolio.transactions.where(kind: "starting_capital")
                             .where("note LIKE ?", "%Stock%").exists?
        unless has_stock_capital
          portfolio.transactions.create!(
            kind: "starting_capital",
            amount: stock_portfolio.starting_capital,
            note: "Stock market unlocked",
            created_at: stock_portfolio.created_at
          )
        end
      end
    end
  end
end
