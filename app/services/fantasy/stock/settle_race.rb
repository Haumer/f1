module Fantasy
  module Stock
    class SettleRace
      # Flat base dividends per share (position-based, same for everyone)
      DIVIDEND_BASES = { 1 => 1.25, 2 => 0.75, 3 => 0.50 }.freeze
      # Surprise bonus rates (price-based, only when overperforming)
      DIVIDEND_RATES = { 1 => 0.005, 2 => 0.003, 3 => 0.002 }.freeze
      POINTS_DIVIDEND_BASE = 0.25  # P4-P10 flat base
      POINTS_DIVIDEND_RATE = 0.001 # P4-P10 surprise bonus rate
      SURPRISE_SCALE = 0.3 # Dampening factor for surprise bonus

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
        portfolio.active_longs.each do |holding|
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
        portfolio.active_shorts.each do |holding|
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
        portfolio.active_shorts.reload.each do |holding|
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

        driver_ids.each do |driver_id|
          driver = Driver.find(driver_id)
          sd = SeasonDriver.find_by(driver_id: driver_id, season_id: season.id)
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

      # Dividend = flat_base + (share_price × rate × √(surprise-1) × 0.3)
      # Surprise = elo_rank - finish_position + 1 (min 1)
      # At 1x (no overperformance), everyone gets the same flat base
      def calculate_dividend(driver, position, portfolio)
        base = DIVIDEND_BASES[position] || (position <= 10 ? POINTS_DIVIDEND_BASE : 0)
        return 0 if base.zero?

        rate = DIVIDEND_RATES[position] || (position <= 10 ? POINTS_DIVIDEND_RATE : 0)
        elo_rank = @elo_ranks[driver.id] || 1
        surprise = [elo_rank - position + 1, 1].max
        bonus = if surprise > 1
          share_price = portfolio.share_price(driver)
          share_price * rate * Math.sqrt(surprise - 1) * SURPRISE_SCALE
        else
          0
        end

        base + bonus
      end
    end
  end
end
