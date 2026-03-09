module Fantasy
  class ReplayTransactions
    def initialize(season:, dry_run: false)
      @season = season
      @dry_run = dry_run
      @results = []
    end

    def call
      portfolios = FantasyPortfolio.where(season: @season)
                     .includes(:user, :transactions, roster_entries: :driver)

      portfolios.each do |portfolio|
        replay_portfolio(portfolio)
      end

      @results
    end

    private

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
