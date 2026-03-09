module Fantasy
  class ReplayTransactions
    def initialize(season:, dry_run: false, reprice: false)
      @season = season
      @dry_run = dry_run
      @reprice = reprice
      @results = []
    end

    def call
      reprice_all if @reprice

      portfolios = FantasyPortfolio.where(season: @season)
                     .includes(:user, :transactions, roster_entries: :driver)

      portfolios.each do |portfolio|
        replay_portfolio(portfolio)
      end

      @results
    end

    private

    # Reprice all trades to use the correct elo at time of trade
    def reprice_all
      puts "Repricing all trades to match recomputed elos..."

      # Build a lookup: driver_id -> [[race_date, new_elo_v2], ...]
      elo_history = RaceResult.joins(:race)
                      .where.not(new_elo_v2: nil)
                      .order("races.date ASC, races.round ASC")
                      .pluck(:driver_id, "races.date", :new_elo_v2)
                      .group_by(&:first)
                      .transform_values { |rows| rows.map { |_, date, elo| [date, elo] } }

      # Helper: find elo at a given date
      find_elo = ->(driver_id, date) {
        history = elo_history[driver_id]
        return EloRatingV2::STARTING_ELO unless history
        # Find the last entry on or before this date
        entry = history.select { |d, _| d <= date }.last
        entry ? entry[1] : EloRatingV2::STARTING_ELO
      }

      changes = 0

      ActiveRecord::Base.transaction do
        # 1. Reprice roster buy transactions and roster entries
        FantasyTransaction.where(kind: "buy", fantasy_portfolio_id: FantasyPortfolio.where(season: @season).select(:id))
          .includes(:driver).each do |txn|
          correct_elo = find_elo.call(txn.driver_id, txn.created_at.to_date)
          correct_amount = -correct_elo # roster price = elo
          next if (txn.amount - correct_amount).abs < 0.01

          puts "  Roster buy #{txn.driver.fullname}: #{txn.amount.round(1)} -> #{correct_amount.round(1)}" unless @dry_run
          txn.update_column(:amount, correct_amount) unless @dry_run
          changes += 1

          # Also update the roster entry's bought_at_elo
          entry = FantasyRosterEntry.find_by(
            fantasy_portfolio_id: txn.fantasy_portfolio_id,
            driver_id: txn.driver_id, active: true
          )
          entry&.update_column(:bought_at_elo, correct_elo) unless @dry_run
        end

        # 2. Reprice stock buy transactions and holdings
        FantasyStockTransaction.where(kind: "buy", fantasy_stock_portfolio_id: FantasyStockPortfolio.where(season: @season).select(:id))
          .includes(:driver).each do |txn|
          correct_elo = find_elo.call(txn.driver_id, txn.created_at.to_date)
          correct_price = correct_elo / FantasyStockPortfolio::PRICE_DIVISOR
          correct_amount = -(correct_price * txn.quantity)
          next if (txn.amount - correct_amount).abs < 0.01

          puts "  Stock buy #{txn.quantity}x #{txn.driver.fullname}: #{txn.amount.round(1)} -> #{correct_amount.round(1)}" unless @dry_run
          unless @dry_run
            txn.update_columns(amount: correct_amount, price: correct_price)
          end
          changes += 1
        end

        # 3. Reprice stock short_open transactions (amount stays 0, but update price)
        FantasyStockTransaction.where(kind: "short_open", fantasy_stock_portfolio_id: FantasyStockPortfolio.where(season: @season).select(:id))
          .includes(:driver).each do |txn|
          correct_elo = find_elo.call(txn.driver_id, txn.created_at.to_date)
          correct_price = correct_elo / FantasyStockPortfolio::PRICE_DIVISOR
          next if (txn.price - correct_price).abs < 0.01

          correct_collateral = (correct_price * txn.quantity * FantasyStockPortfolio::COLLATERAL_RATIO).round(1)
          puts "  Short #{txn.quantity}x #{txn.driver.fullname}: price #{txn.price.round(1)} -> #{correct_price.round(1)}" unless @dry_run
          unless @dry_run
            txn.update_columns(
              price: correct_price,
              note: "Shorted #{txn.quantity}x #{txn.driver.fullname} at #{correct_price.round(1)} (#{correct_collateral} collateral locked)"
            )
          end
          changes += 1
        end

        # 4. Update stock holding entry prices and collateral
        FantasyStockHolding.where(fantasy_stock_portfolio_id: FantasyStockPortfolio.where(season: @season).select(:id), active: true)
          .includes(:driver, :fantasy_stock_portfolio).each do |h|
          # Find the trade transaction to get the correct date
          txn = h.fantasy_stock_portfolio.transactions
                  .where(driver: h.driver, kind: %w[buy short_open])
                  .order(:created_at).last
          next unless txn

          correct_elo = find_elo.call(h.driver_id, txn.created_at.to_date)
          correct_price = correct_elo / FantasyStockPortfolio::PRICE_DIVISOR
          next if (h.entry_price - correct_price).abs < 0.01

          puts "  Holding #{h.direction} #{h.quantity}x #{h.driver.fullname}: entry #{h.entry_price.round(1)} -> #{correct_price.round(1)}" unless @dry_run
          unless @dry_run
            attrs = { entry_price: correct_price }
            if h.direction == "short"
              attrs[:collateral] = correct_price * h.quantity * FantasyStockPortfolio::COLLATERAL_RATIO
            end
            h.update_columns(attrs)
          end
          changes += 1
        end
      end

      puts "Repriced #{changes} records."
    end

    def replay_portfolio(portfolio)
      sp = FantasyStockPortfolio.find_by(user_id: portfolio.user_id, season_id: @season.id)
      old_cash = portfolio.cash

      # Step 1: Backfill starting_capital transactions if missing
      backfill_starting_capital(portfolio, sp)

      # Step 2: Gather ALL transactions (roster + stock) sorted by timestamp
      all_txns = portfolio.transactions.reload.order(:created_at).to_a
      if sp
        stock_txns = sp.transactions.order(:created_at).to_a
        all_txns = (all_txns + stock_txns).sort_by(&:created_at)
      end

      # Step 3: Replay from zero
      cash = 0.0
      all_txns.each do |txn|
        cash += txn.amount
      end

      # Step 4: Recompute collateral on active shorts
      old_collaterals = {}
      if sp
        sp.active_shorts.includes(:driver).each do |h|
          price = sp.share_price(h.driver)
          correct = price * h.quantity * FantasyStockPortfolio::COLLATERAL_RATIO
          old_collaterals[h.id] = { old: h.collateral, new: correct }
        end
      end

      @results << {
        user: portfolio.user.username,
        old_cash: old_cash.round(2),
        new_cash: cash.round(2),
        diff: (cash - old_cash).round(2),
        txn_count: all_txns.size,
        collateral_changes: old_collaterals.select { |_, v| (v[:old] - v[:new]).abs > 0.01 }
      }

      unless @dry_run
        ActiveRecord::Base.transaction do
          portfolio.update!(cash: cash)
          old_collaterals.each do |holding_id, vals|
            next if (vals[:old] - vals[:new]).abs < 0.01
            FantasyStockHolding.find(holding_id).update!(collateral: vals[:new])
          end
        end
      end
    end

    def backfill_starting_capital(portfolio, stock_portfolio)
      # Roster starting capital
      unless portfolio.transactions.exists?(kind: "starting_capital")
        portfolio.transactions.create!(
          kind: "starting_capital",
          amount: portfolio.starting_capital,
          note: "Roster starting capital",
          created_at: portfolio.created_at
        )
      end

      # Stock starting capital (recorded as roster transaction since cash goes to wallet)
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
