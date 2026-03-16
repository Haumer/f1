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
      @races = @season.races.joins(:race_results).distinct.order(:round).to_a
      raise "No races with results for season #{@season.year}" if @races.empty?

      @drivers_by_id = Driver.where(active: true).index_by(&:id)
      @stock_portfolio_scope = FantasyStockPortfolio.where(season: @season)
      @roster_portfolio_scope = FantasyPortfolio.where(season: @season)
      @demand = Hash.new(0)

      ActiveRecord::Base.transaction do
        reset_state
        load_user_trades

        # Build cutoffs: use when results were actually synced (not starts_at),
        # because trades before sync used pre-race Elo (it was still live)
        @race_cutoffs = @races.map do |race|
          RaceResult.where(race: race).minimum(:created_at) || race.starts_at || race.date.beginning_of_day
        end

        @races.each_with_index do |race, idx|
          puts "\n=== Round #{race.round} (#{race.date}) ==="
          race_cutoff = @race_cutoffs[idx]
          prev_cutoff = idx == 0 ? Time.at(0) : @race_cutoffs[idx - 1]

          # Elo for pricing trades in this window:
          # Before R1 → pre-R1 Elo (old_elo_v2)
          # Between RN and RN+1 → post-RN Elo (new_elo_v2 from RN)
          elo_map = if idx == 0
            RaceResult.where(race: race).pluck(:driver_id, :old_elo_v2).to_h
          else
            RaceResult.where(race: @races[idx - 1]).pluck(:driver_id, :new_elo_v2).to_h
          end

          # Reprice stock trades that happened before this race
          window_stock = @stock_trades.select { |t| t.created_at >= prev_cutoff && t.created_at < race_cutoff }
          reprice_stock_in_window(window_stock, elo_map)

          # Update holdings entry prices from all repriced trades so far
          update_holdings_entry_prices

          # Settle this race (dividends, borrow fees, margin calls)
          post_elo = RaceResult.where(race: race).pluck(:driver_id, :new_elo_v2).to_h
          results_by_driver = RaceResult.where(race: race).index_by(&:driver_id)
          settle_for_replay(race, post_elo, results_by_driver)

          # Snapshot this race
          snapshot_for_replay(race, post_elo)
        end

        # Reprice trades after the last race (if any)
        last_cutoff = @race_cutoffs.last
        last_elo = RaceResult.where(race: @races.last).pluck(:driver_id, :new_elo_v2).to_h
        remaining_stock = @stock_trades.select { |t| t.created_at >= last_cutoff }
        if remaining_stock.any?
          puts "\n=== Post-season trades ==="
          reprice_stock_in_window(remaining_stock, last_elo)
          update_holdings_entry_prices
        end

        # Persist final demand
        @demand.each do |driver_id, net|
          SeasonDriver.where(season: @season, driver_id: driver_id).update_all(net_demand: net)
        end
        puts "\nFinal demand persisted"
      end
    end

    # ── Reset state ──────────────────────────────────────────────────────

    def reset_state
      # Reset demand
      SeasonDriver.where(season: @season).update_all(net_demand: 0)
      puts "Reset net_demand to 0"

      # Collect liquidated holdings before deleting their transactions
      liquidated = FantasyStockTransaction.where(
        fantasy_stock_portfolio_id: @stock_portfolio_scope.select(:id),
        kind: "liquidation"
      ).pluck(:fantasy_stock_portfolio_id, :driver_id, :race_id)

      # Delete all settlement transactions (will be recreated per race)
      deleted = FantasyStockTransaction.where(
        fantasy_stock_portfolio_id: @stock_portfolio_scope.select(:id),
        kind: %w[dividend borrow_fee liquidation]
      ).delete_all
      puts "Deleted #{deleted} settlement transactions"

      # Reopen holdings that were closed by liquidation
      liquidated.each do |portfolio_id, driver_id, race_id|
        FantasyStockHolding.where(
          fantasy_stock_portfolio_id: portfolio_id,
          driver_id: driver_id,
          closed_race_id: race_id,
          active: false
        ).update_all(active: true, closed_race_id: nil, collateral: 0)
      end
      puts "Reopened #{liquidated.size} liquidated holdings" if liquidated.any?

      # Delete snapshots for all completed races
      race_ids = @races.map(&:id)
      FantasySnapshot.where(race_id: race_ids).delete_all
      FantasyStockSnapshot.where(race_id: race_ids).delete_all
      StockPriceSnapshot.where(race_id: race_ids).delete_all
      puts "Deleted snapshots"
    end

    def load_user_trades
      @stock_trades = FantasyStockTransaction.where(
        fantasy_stock_portfolio_id: @stock_portfolio_scope.select(:id),
        kind: %w[buy sell short_open short_close]
      ).includes(:driver).order(:created_at).to_a

      puts "Loaded #{@stock_trades.size} stock trades"
    end

    # ── Reprice trades in a time window ──────────────────────────────────

    def reprice_stock_in_window(trades, elo_map)
      changes = 0
      trades.each do |txn|
        elo = elo_map[txn.driver_id] || EloRatingV2::STARTING_ELO
        base = elo / FantasyStockPortfolio::PRICE_DIVISOR
        price = base * Fantasy::Pricing.demand_multiplier(@demand[txn.driver_id])
        name = @drivers_by_id[txn.driver_id]&.fullname || txn.driver_id

        case txn.kind
        when "buy"
          correct_amount = -(price * txn.quantity)
          puts "  Stock buy #{txn.quantity}x #{name}: #{txn.amount.round(1)} -> #{correct_amount.round(1)} (demand=#{@demand[txn.driver_id]})"
          txn.update_columns(amount: correct_amount, price: price)
          @demand[txn.driver_id] += txn.quantity
        when "sell"
          correct_amount = price * txn.quantity
          puts "  Stock sell #{txn.quantity}x #{name}: #{txn.amount.round(1)} -> #{correct_amount.round(1)} (demand=#{@demand[txn.driver_id]})"
          txn.update_columns(amount: correct_amount, price: price)
          @demand[txn.driver_id] -= txn.quantity
        when "short_open"
          collateral = (price * txn.quantity * FantasyStockPortfolio::COLLATERAL_RATIO).round(1)
          puts "  Short open #{txn.quantity}x #{name}: #{txn.price&.round(1)} -> #{price.round(1)} (demand=#{@demand[txn.driver_id]})"
          txn.update_columns(
            price: price, amount: 0,
            note: "Shorted #{txn.quantity}x #{name} at #{price.round(1)} (#{collateral} collateral locked)"
          )
          @demand[txn.driver_id] -= txn.quantity
        when "short_close"
          puts "  Short close #{txn.quantity}x #{name}: #{txn.price&.round(1)} -> #{price.round(1)} (demand=#{@demand[txn.driver_id]})"
          txn.update_columns(price: price)
          @demand[txn.driver_id] += txn.quantity
        end
        changes += 1
      end
      puts "  Repriced #{changes} stock trades" if changes > 0
    end

    # ── Update holdings from repriced trades ─────────────────────────────

    def update_holdings_entry_prices
      holdings = FantasyStockHolding.where(
        fantasy_stock_portfolio_id: @stock_portfolio_scope.select(:id), active: true
      ).includes(:driver)

      # Group opening trades by [portfolio_id, driver_id]
      opening_trades = FantasyStockTransaction.where(
        kind: %w[buy short_open],
        fantasy_stock_portfolio_id: @stock_portfolio_scope.select(:id)
      ).order(:created_at).group_by { |t| [t.fantasy_stock_portfolio_id, t.driver_id] }

      changes = 0
      holdings.each do |h|
        txns = opening_trades[[h.fantasy_stock_portfolio_id, h.driver_id]] || []
        next if txns.empty?

        if txns.size == 1
          correct_price = txns.first.price
        else
          total_qty = txns.sum(&:quantity)
          total_cost = txns.sum { |t| t.price * t.quantity }
          correct_price = total_cost / total_qty
        end

        attrs = {}
        attrs[:entry_price] = correct_price if (h.entry_price - correct_price).abs > 0.001
        if h.direction == "short"
          correct_collateral = correct_price * h.quantity * FantasyStockPortfolio::COLLATERAL_RATIO
          attrs[:collateral] = correct_collateral if (h.collateral.to_f - correct_collateral).abs > 0.01
        end

        if attrs.any?
          name = @drivers_by_id[h.driver_id]&.fullname || h.driver_id
          puts "  Holding #{h.direction} #{h.quantity}x #{name}: entry #{h.entry_price.round(1)} -> #{correct_price.round(1)}" if attrs[:entry_price]
          h.update_columns(attrs)
          changes += 1
        end
      end

      # Fix short_close transaction amounts now that entry_prices are correct
      fix_short_close_amounts

      puts "  Updated #{changes} holdings" if changes > 0
    end

    def fix_short_close_amounts
      close_txns = FantasyStockTransaction.where(
        kind: "short_close",
        fantasy_stock_portfolio_id: @stock_portfolio_scope.select(:id)
      ).to_a
      return if close_txns.empty?

      close_txns.each do |txn|
        holding = FantasyStockHolding.find_by(
          fantasy_stock_portfolio_id: txn.fantasy_stock_portfolio_id,
          driver_id: txn.driver_id,
          direction: "short"
        )
        entry_price = holding&.entry_price
        unless entry_price
          opens = FantasyStockTransaction.where(
            kind: "short_open",
            fantasy_stock_portfolio_id: txn.fantasy_stock_portfolio_id,
            driver_id: txn.driver_id
          )
          entry_price = opens.any? ? opens.sum { |t| t.price * t.quantity } / opens.sum(&:quantity) : txn.price
        end

        correct_amount = (entry_price - txn.price) * txn.quantity
        next if (txn.amount - correct_amount).abs < 0.01
        name = @drivers_by_id[txn.driver_id]&.fullname || txn.driver_id
        puts "  Short close P&L #{name}: #{txn.amount.round(2)} -> #{correct_amount.round(2)}"
        txn.update_column(:amount, correct_amount)
      end
    end

    # ── Settle a race (dividends, borrow fees, margin calls) ─────────────

    def settle_for_replay(race, post_elo, results_by_driver)
      race_cutoff = race.starts_at || race.date
      settle_time = (race.starts_at || race.date.to_time) + 4.hours

      pre_elo = RaceResult.where(race: race).pluck(:driver_id, :old_elo_v2).to_h
      elo_ranks = pre_elo.sort_by { |_, elo| -(elo || 0) }
                    .each_with_index
                    .to_h { |(id, _), idx| [id, idx + 1] }

      constructor_mults = build_constructor_mults(race)

      stock_portfolios = FantasyStockPortfolio.where(season: @season)
                           .includes(holdings: :driver)

      stock_portfolios.each do |portfolio|
        # Dividends: only for longs that existed before this race
        eligible_longs = portfolio.holdings.select { |h|
          h.active && h.direction == "long" && h.created_at < race_cutoff
        }
        eligible_longs.each do |holding|
          rr = results_by_driver[holding.driver_id]
          next unless rr&.position_order && rr.position_order <= 10

          constructor_mult = constructor_mults[holding.driver_id] || 2.5
          elo_rank = elo_ranks[holding.driver_id] || 1
          overperformance = [elo_rank - rr.position_order, 0].max
          dividend_per_share = Fantasy::Stock::SettleRace::DIVIDEND_BASE * constructor_mult +
                               Fantasy::Stock::SettleRace::DIVIDEND_SURPRISE_BONUS * overperformance
          next if dividend_per_share <= 0

          total = (dividend_per_share * holding.quantity).round(2)
          portfolio.transactions.create!(
            kind: "dividend",
            driver: holding.driver,
            race: race,
            quantity: holding.quantity,
            price: dividend_per_share.round(2),
            amount: total,
            note: "Dividend: P#{rr.position_order} #{holding.driver.fullname} (#{holding.quantity}x #{dividend_per_share.round(2)})",
            created_at: settle_time
          )
          puts "  Dividend: #{holding.driver.fullname} P#{rr.position_order} -> #{total.round(2)} (#{holding.quantity}x)"
        end

        # Borrow fees: only for shorts that existed before this race
        eligible_shorts = portfolio.holdings.select { |h|
          h.active && h.direction == "short" && h.created_at < race_cutoff
        }
        eligible_shorts.each do |holding|
          fee_per_share = holding.entry_price * Fantasy::Stock::SettleRace::BORROW_FEE_RATE
          total_fee = (fee_per_share * holding.quantity).round(2)

          portfolio.transactions.create!(
            kind: "borrow_fee",
            driver: holding.driver,
            race: race,
            quantity: holding.quantity,
            price: fee_per_share,
            amount: -total_fee,
            note: "Borrow fee: #{holding.quantity}x #{holding.driver.fullname} (#{Fantasy::Stock::SettleRace::BORROW_FEE_RATE * 100}%)",
            created_at: settle_time
          )
          puts "  Borrow fee: #{holding.driver.fullname} #{holding.quantity}x -> -#{total_fee.round(2)}"
        end

        # Margin calls: check shorts that existed before this race
        eligible_shorts.each do |holding|
          elo = post_elo[holding.driver_id] || holding.driver.elo_v2
          net = @demand[holding.driver_id]
          current_price = Fantasy::Pricing.stock_price_for_elo(elo, net)
          max_price = holding.entry_price * (1 + Fantasy::Stock::SettleRace::MAX_LOSS_MULTIPLIER)

          next unless current_price >= max_price

          loss = (holding.entry_price - current_price) * holding.quantity
          holding.update!(active: false, closed_race: race, collateral: 0)

          portfolio.transactions.create!(
            kind: "liquidation",
            driver: holding.driver,
            race: race,
            quantity: holding.quantity,
            price: current_price,
            amount: loss,
            note: "Margin call: #{holding.driver.fullname} hit #{Fantasy::Stock::SettleRace::MAX_LOSS_MULTIPLIER}x max loss, auto-closed",
            created_at: settle_time
          )
          @demand[holding.driver_id] += holding.quantity
          puts "  LIQUIDATION: #{holding.driver.fullname} #{holding.quantity}x at #{current_price.round(1)}"
        end
      end
    end

    def build_constructor_mults(race)
      mults = {}
      prev_season = race.season.previous_season
      return mults unless prev_season

      last_race = Race.where(season: prev_season).order(:round).last
      return mults unless last_race

      SeasonDriver.where(season_id: race.season_id).each do |sd|
        next unless sd.constructor_id
        cs = ConstructorStanding.find_by(constructor_id: sd.constructor_id, race_id: last_race.id)
        pos = (cs&.position || 5).clamp(1, 10)
        mults[sd.driver_id] = Fantasy::Stock::SettleRace::CONSTRUCTOR_MULT_MIN +
          (pos - 1) * ((Fantasy::Stock::SettleRace::CONSTRUCTOR_MULT_MAX - Fantasy::Stock::SettleRace::CONSTRUCTOR_MULT_MIN) / 9.0)
      end
      mults
    end

    # ── Snapshot a race ──────────────────────────────────────────────────

    def snapshot_for_replay(race, post_elo)
      Fantasy::SnapshotPortfolios.new(race: race).call
      puts "  Snapshots created"

      # Stock price snapshots
      driver_ids = FantasyStockHolding.where(
        fantasy_stock_portfolio_id: @stock_portfolio_scope.select(:id), active: true
      ).distinct.pluck(:driver_id)

      driver_ids.each do |driver_id|
        elo = post_elo[driver_id] || @drivers_by_id[driver_id]&.elo_v2 || EloRatingV2::STARTING_ELO
        net = @demand[driver_id]
        price = Fantasy::Pricing.stock_price_for_elo(elo, net)
        StockPriceSnapshot.find_or_create_by!(driver_id: driver_id, race: race) do |snap|
          snap.elo = elo
          snap.net_demand = net
          snap.price = price
        end
      end
      puts "  Stock price snapshots created"
    end

    # ── Replay cash from all transactions ────────────────────────────────

    def replay_cash
      portfolios = FantasyPortfolio.where(season: @season)
                     .includes(:user, :transactions)

      portfolios.each do |portfolio|
        replay_portfolio(portfolio)
      end
    end

    def replay_portfolio(portfolio)
      sp = FantasyStockPortfolio.find_by(user_id: portfolio.user_id, season_id: @season.id)
      old_cash = portfolio.cash

      backfill_starting_capital(portfolio)

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

    def backfill_starting_capital(portfolio)
      unless portfolio.transactions.exists?(kind: "starting_capital")
        portfolio.transactions.create!(
          kind: "starting_capital",
          amount: portfolio.starting_capital,
          note: "Starting capital",
          created_at: portfolio.created_at
        )
      end
    end
  end
end
