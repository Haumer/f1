module Fantasy
  module Stock
    class SettleRace
      DIVIDEND_RATES = { 1 => 0.005, 2 => 0.003, 3 => 0.002 }.freeze
      POINTS_DIVIDEND_RATE = 0.001 # P4-P10
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

        portfolios.each do |portfolio|
          ActiveRecord::Base.transaction do
            # Lock the portfolio row to prevent concurrent settlement
            portfolio.lock!

            # Idempotency: skip if already settled for this race
            next if portfolio.snapshots.exists?(race: @race)

            pay_dividends(portfolio, results_by_driver)
            charge_borrow_fees(portfolio)
            check_margin_calls(portfolio)
            snapshot(portfolio)
          end
        end
      end

      private

      def pay_dividends(portfolio, results_by_driver)
        portfolio.active_longs.each do |holding|
          rr = results_by_driver[holding.driver_id]
          next unless rr

          rate = dividend_rate_for_position(rr.position_order)
          next if rate.zero?

          share_price = portfolio.share_price(holding.driver)
          dividend_per_share = (share_price * rate).round(2)
          total = dividend_per_share * holding.quantity
          portfolio.update!(cash: portfolio.cash + total)

          portfolio.transactions.create!(
            kind: "dividend",
            driver: holding.driver,
            race: @race,
            quantity: holding.quantity,
            price: dividend_per_share,
            amount: total,
            note: "Dividend: P#{rr.position_order} #{holding.driver.fullname} (#{holding.quantity}x #{dividend_per_share})"
          )
        end
      end

      def charge_borrow_fees(portfolio)
        portfolio.active_shorts.each do |holding|
          fee_per_share = holding.entry_price * BORROW_FEE_RATE
          total_fee = fee_per_share * holding.quantity

          new_cash = [portfolio.cash - total_fee, 0].max
          actual_fee = portfolio.cash - new_cash
          portfolio.update!(cash: new_cash)

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
        portfolio.active_shorts.reload.each do |holding|
          current = portfolio.share_price(holding.driver)
          max_price = holding.entry_price * (1 + MAX_LOSS_MULTIPLIER)

          next unless current >= max_price

          # Auto-liquidate — cap loss so cash doesn't go negative
          loss = (holding.entry_price - current) * holding.quantity
          new_cash = [portfolio.cash + loss, 0].max
          actual_loss = new_cash - portfolio.cash

          holding.update!(active: false, closed_race: @race, collateral: 0)
          portfolio.update!(cash: new_cash)

          portfolio.transactions.create!(
            kind: "liquidation",
            driver: holding.driver,
            race: @race,
            quantity: holding.quantity,
            price: current,
            amount: actual_loss,
            note: "Margin call: #{holding.driver.fullname} hit #{MAX_LOSS_MULTIPLIER}x max loss, auto-closed"
          )
        end
      end

      def snapshot(portfolio)
        value = portfolio.reload.portfolio_value
        FantasyStockSnapshot.find_or_initialize_by(
          fantasy_stock_portfolio: portfolio,
          race: @race
        ).update!(value: value, cash: portfolio.cash)
      end

      def dividend_rate_for_position(position)
        return 0 unless position
        DIVIDEND_RATES[position] || (position <= 10 ? POINTS_DIVIDEND_RATE : 0)
      end
    end
  end
end
