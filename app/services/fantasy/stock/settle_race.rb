module Fantasy
  module Stock
    class SettleRace
      # Money-math constants live on Fantasy::Stock::SettlementCalculator.
      # Aliased here for callers/tests/views that reference SettleRace::*.
      DIVIDEND_BASE = SettlementCalculator::DIVIDEND_BASE
      DIVIDEND_SURPRISE_BONUS = SettlementCalculator::DIVIDEND_SURPRISE_BONUS
      CONSTRUCTOR_MULT_MIN = SettlementCalculator::CONSTRUCTOR_MULT_MIN
      CONSTRUCTOR_MULT_MAX = SettlementCalculator::CONSTRUCTOR_MULT_MAX
      BORROW_FEE_RATE = SettlementCalculator::BORROW_FEE_RATE
      MAX_LOSS_MULTIPLIER = SettlementCalculator::MAX_LOSS_MULTIPLIER

      def initialize(race:)
        @race = race
      end

      def call
        portfolios = FantasyStockPortfolio.where(season: @race.season)
                       .includes(holdings: :driver)

        results_by_driver = RaceResult.where(race: @race)
                              .index_by(&:driver_id)

        # Historical Elo map for snapshots
        @elo_map = results_by_driver.transform_values(&:new_elo_v2)

        # Rank drivers by Elo for surprise factor calculation
        @elo_ranks = Driver.where(active: true)
                       .order(elo_v2: :desc)
                       .pluck(:id)
                       .each_with_index
                       .to_h { |id, idx| [id, idx + 1] }

        preload_constructor_multipliers!

        portfolios.each do |portfolio|
          ActiveRecord::Base.transaction do
            # Lock both the stock portfolio and its wallet (roster portfolio)
            portfolio.lock!
            portfolio.wallet&.lock!

            # Idempotency: skip if already settled (dividends/fees paid) for this race
            next if portfolio.transactions.where(race: @race, kind: %w[dividend borrow_fee liquidation]).exists?

            pay_dividends(portfolio, results_by_driver)
            charge_borrow_fees(portfolio)
            check_margin_calls(portfolio)
            snapshot(portfolio)
          end
        end

        snapshot_prices(portfolios)
        assign_snapshot_ranks
      end

      private

      def pay_dividends(portfolio, results_by_driver)
        wallet = portfolio.wallet
        return unless wallet
        # Only pay dividends for holdings that existed before this race
        eligible_longs = portfolio.active_longs.before_race(@race)
        eligible_longs.each do |holding|
          rr = results_by_driver[holding.driver_id]
          next unless rr
          next unless rr.position_order && rr.position_order <= 10

          calc = dividend_breakdown(holding.driver, rr.position_order)
          next if calc[:per_share] <= 0

          total = (calc[:per_share] * holding.quantity).round(2)
          wallet.update!(cash: wallet.cash + total)

          portfolio.transactions.create!(
            kind: "dividend",
            driver: holding.driver,
            race: @race,
            quantity: holding.quantity,
            price: calc[:per_share].round(2),
            amount: total,
            note: dividend_note(rr.position_order, holding, calc)
          )
        end
      end

      def dividend_note(finish, holding, calc)
        base = "Dividend: P#{finish} #{holding.driver.fullname} (#{holding.quantity}x #{calc[:per_share].round(2)})"
        return base if calc[:overperformance] <= 0

        "#{base} — beat Elo rank P#{calc[:elo_rank]} by #{calc[:overperformance]}"
      end

      def charge_borrow_fees(portfolio)
        wallet = portfolio.wallet
        return unless wallet
        # Only charge fees for shorts that existed before this race
        eligible_shorts = portfolio.active_shorts.before_race(@race)
        eligible_shorts.each do |holding|
          fee_per_share = SettlementCalculator.borrow_fee_per_share(entry_price: holding.entry_price)
          total_fee = fee_per_share * holding.quantity

          new_cash = [wallet.cash - total_fee, 0].max
          actual_fee = wallet.cash - new_cash
          wallet.update!(cash: new_cash)

          portfolio.transactions.create!(
            kind: "borrow_fee",
            driver: holding.driver,
            race: @race,
            quantity: holding.quantity,
            price: fee_per_share,
            amount: -actual_fee,
            note: "Borrow fee: #{holding.quantity}x #{holding.driver.fullname} (#{BORROW_FEE_RATE * 100}%)"
          )
        end
      end

      def check_margin_calls(portfolio)
        wallet = portfolio.wallet
        return unless wallet
        # Only check shorts that existed before this race
        portfolio.active_shorts.before_race(@race).reload.each do |holding|
          current = portfolio.share_price(holding.driver)
          max_price = SettlementCalculator.margin_call_price(entry_price: holding.entry_price)

          next unless current >= max_price

          # Auto-liquidate — cap loss so cash doesn't go negative
          loss = (holding.entry_price - current) * holding.quantity
          new_cash = [wallet.cash + loss, 0].max
          actual_loss = new_cash - wallet.cash

          holding.update!(active: false, closed_race: @race, collateral: 0)
          wallet.update!(cash: new_cash)

          portfolio.transactions.create!(
            kind: "liquidation",
            driver: holding.driver,
            race: @race,
            quantity: holding.quantity,
            price: current,
            amount: actual_loss,
            note: "Margin call: #{holding.driver.fullname} hit #{MAX_LOSS_MULTIPLIER}x max loss, auto-closed"
          )

          # Closing a short increases net demand
          SeasonDriver.adjust_demand!(holding.driver_id, portfolio.season_id, holding.quantity)
        end
      end

      def snapshot(portfolio)
        # Compute positions value using historical Elo
        season_drivers = SeasonDriver.where(season_id: @race.season_id).index_by(&:driver_id)
        active = portfolio.holdings.loaded? ? portfolio.holdings.select(&:active) : portfolio.active_holdings.includes(:driver).to_a

        longs_value = active.select { |h| h.direction == "long" }.sum do |h|
          elo = @elo_map[h.driver_id] || h.driver.elo_v2
          net_demand = season_drivers[h.driver_id]&.net_demand || 0
          Fantasy::Pricing.stock_price_for_elo(elo, net_demand) * h.quantity
        end

        shorts_pnl = active.select { |h| h.direction == "short" }.sum do |h|
          elo = @elo_map[h.driver_id] || h.driver.elo_v2
          net_demand = season_drivers[h.driver_id]&.net_demand || 0
          (h.entry_price - Fantasy::Pricing.stock_price_for_elo(elo, net_demand)) * h.quantity
        end

        value = longs_value + shorts_pnl
        FantasyStockSnapshot.find_or_initialize_by(
          fantasy_stock_portfolio: portfolio,
          race: @race
        ).update!(value: value, cash: 0)
      end

      # Snapshot stock prices for all drivers with active holdings
      def snapshot_prices(portfolios)
        return if StockPriceSnapshot.exists?(race: @race)

        driver_ids = portfolios.flat_map { |p| p.holdings.select(&:active).map(&:driver_id) }.uniq
        season = @race.season
        drivers_by_id = Driver.where(id: driver_ids).index_by(&:id)
        season_drivers_by_driver = SeasonDriver.where(driver_id: driver_ids, season_id: season.id).index_by(&:driver_id)

        driver_ids.each do |driver_id|
          driver = drivers_by_id[driver_id]
          next unless driver
          sd = season_drivers_by_driver[driver_id]
          net = sd&.net_demand || 0
          elo = @elo_map[driver_id] || driver.elo_v2
          price = Fantasy::Pricing.stock_price_for_elo(elo, net)

          StockPriceSnapshot.create!(
            driver_id: driver_id,
            race: @race,
            elo: elo,
            net_demand: net,
            price: price
          )
        end
      end

      def dividend_breakdown(driver, position)
        SettlementCalculator.dividend_breakdown(
          constructor_mult: constructor_multiplier(driver),
          elo_rank: @elo_ranks[driver.id] || 1,
          position: position
        )
      end

      # Rank portfolios by snapshot value for this race. Cheap pluck + bulk update.
      def assign_snapshot_ranks
        snaps = FantasyStockSnapshot.where(race: @race).order(value: :desc).pluck(:id, :value)
        snaps.each_with_index do |(id, _v), idx|
          FantasyStockSnapshot.where(id: id).update_all(rank: idx + 1)
        end
      end

      def constructor_multiplier(driver)
        @constructor_mults[driver.id] || SettlementCalculator.default_constructor_multiplier
      end

      def preload_constructor_multipliers!
        @constructor_mults = SettlementCalculator.constructor_multipliers_for_race(@race)
      end
    end
  end
end
