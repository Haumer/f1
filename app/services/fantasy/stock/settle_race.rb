module Fantasy
  module Stock
    class SettleRace
      # Constructor-scaled dividends: underdogs pay more
      # dividend = BASE × constructor_mult + SURPRISE_BONUS × overperformance
      DIVIDEND_BASE = 0.10
      DIVIDEND_SURPRISE_BONUS = 0.02
      # Constructor multiplier range: 0.5 (WCC P1) → 5.0 (WCC P10)
      CONSTRUCTOR_MULT_MIN = 0.5
      CONSTRUCTOR_MULT_MAX = 5.0

      BORROW_FEE_RATE = 0.0025 # 0.25% per race
      MAX_LOSS_MULTIPLIER = 2.0 # Auto-liquidate at 2x entry price loss

      def initialize(race:)
        @race = race
      end

      def call
        portfolios = FantasyStockPortfolio.where(season: @race.season)
                       .includes(holdings: :driver)

        results_by_driver = RaceResult.where(race: @race)
                              .index_by(&:driver_id)

        # Rank drivers by Elo for surprise factor calculation
        @elo_ranks = Driver.where(active: true)
                       .order(elo_v2: :desc)
                       .pluck(:id)
                       .each_with_index
                       .to_h { |id, idx| [id, idx + 1] }

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
      end

      private

      def pay_dividends(portfolio, results_by_driver)
        wallet = portfolio.wallet
        return unless wallet
        # Only pay dividends for holdings that existed before this race
        eligible_longs = portfolio.active_longs.where("created_at < ?", @race.starts_at || @race.date)
        eligible_longs.each do |holding|
          rr = results_by_driver[holding.driver_id]
          next unless rr
          next unless rr.position_order && rr.position_order <= 10

          dividend_per_share = calculate_dividend(holding.driver, rr.position_order, portfolio)
          next if dividend_per_share <= 0

          total = (dividend_per_share * holding.quantity).round(2)
          wallet.update!(cash: wallet.cash + total)

          portfolio.transactions.create!(
            kind: "dividend",
            driver: holding.driver,
            race: @race,
            quantity: holding.quantity,
            price: dividend_per_share.round(2),
            amount: total,
            note: "Dividend: P#{rr.position_order} #{holding.driver.fullname} (#{holding.quantity}x #{dividend_per_share.round(2)})"
          )
        end
      end

      def charge_borrow_fees(portfolio)
        wallet = portfolio.wallet
        return unless wallet
        # Only charge fees for shorts that existed before this race
        eligible_shorts = portfolio.active_shorts.where("created_at < ?", @race.starts_at || @race.date)
        eligible_shorts.each do |holding|
          fee_per_share = holding.entry_price * BORROW_FEE_RATE
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
        portfolio.active_shorts.where("created_at < ?", @race.starts_at || @race.date).reload.each do |holding|
          current = portfolio.share_price(holding.driver)
          max_price = holding.entry_price * (1 + MAX_LOSS_MULTIPLIER)

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
        value = portfolio.reload.positions_value
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
          price = Fantasy::Pricing.stock_price_for(driver, season)

          StockPriceSnapshot.create!(
            driver_id: driver_id,
            race: @race,
            elo: driver.elo_v2,
            net_demand: net,
            price: price
          )
        end
      end

      # Dividend per top-10 finish = BASE × constructor_mult + SURPRISE_BONUS × overperformance
      # constructor_mult: 0.5 (WCC P1 last year) → 5.0 (WCC P10)
      # overperformance: max(elo_rank - finish_position, 0)
      def calculate_dividend(driver, position, _portfolio)
        return 0 unless position && position <= 10

        constructor_mult = constructor_multiplier(driver)
        elo_rank = @elo_ranks[driver.id] || 1
        overperformance = [elo_rank - position, 0].max

        DIVIDEND_BASE * constructor_mult + DIVIDEND_SURPRISE_BONUS * overperformance
      end

      def constructor_multiplier(driver)
        @constructor_mults ||= {}
        return @constructor_mults[driver.id] if @constructor_mults.key?(driver.id)

        standing_pos = nil
        prev_season = @race.season.previous_season
        if prev_season
          # Find which constructor this driver races for this season
          sd = SeasonDriver.find_by(driver_id: driver.id, season_id: @race.season_id)
          if sd&.constructor_id
            # Standings are per-race — get the last race of previous season
            last_race = Race.where(season: prev_season).order(:round).last
            if last_race
              cs = ConstructorStanding.find_by(constructor_id: sd.constructor_id, race_id: last_race.id)
              standing_pos = cs&.position
            end
          end
        end

        # Default to midfield (position 5) if no data
        standing_pos ||= 5
        standing_pos = standing_pos.clamp(1, 10)

        @constructor_mults[driver.id] = CONSTRUCTOR_MULT_MIN + (standing_pos - 1) * ((CONSTRUCTOR_MULT_MAX - CONSTRUCTOR_MULT_MIN) / 9.0)
      end
    end
  end
end
