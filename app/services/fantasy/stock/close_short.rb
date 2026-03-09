module Fantasy
  module Stock
    class CloseShort
      def initialize(portfolio:, driver:, quantity:, race:)
        @portfolio = portfolio
        @driver = driver
        @quantity = quantity.to_i
        @race = race
      end

      def call
        return { error: "Transfer window is closed" } unless @portfolio.can_trade?(@race)
        return { error: "Invalid quantity" } unless @quantity > 0

        @portfolio.with_lock do
          holding = @portfolio.active_shorts.find_by(driver: @driver)
          return { error: "No short position on this driver" } unless holding
          return { error: "You only have #{holding.quantity} shorted" } if @quantity > holding.quantity

          current_price = @portfolio.share_price(@driver)
          pnl = (holding.entry_price - current_price) * @quantity

          wallet = @portfolio.wallet
          wallet.lock!
          # Prevent cash from going negative
          new_cash = [wallet.cash + pnl, 0].max
          actual_pnl = new_cash - wallet.cash

          # Release proportional collateral
          released_collateral = (holding.collateral.to_f / holding.quantity) * @quantity

          if @quantity == holding.quantity
            holding.update!(active: false, closed_race: @race, collateral: 0)
          else
            holding.update!(
              quantity: holding.quantity - @quantity,
              collateral: holding.collateral - released_collateral
            )
          end

          wallet.update!(cash: new_cash)

          @portfolio.transactions.create!(
            kind: "short_close",
            driver: @driver,
            race: @race,
            quantity: @quantity,
            price: current_price,
            amount: actual_pnl,
            note: "Closed short #{@quantity}x #{@driver.fullname} at #{current_price.round(1)} (P&L: #{actual_pnl >= 0 ? '+' : ''}#{actual_pnl.round(1)})"
          )

          SeasonDriver.adjust_demand!(@driver.id, @portfolio.season_id, @quantity)
        end

        { success: true }
      end
    end
  end
end
