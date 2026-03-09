module Fantasy
  module Stock
    class CloseShort < BaseTrade
      private

      def execute
        holding = @portfolio.active_shorts.find_by(driver: @driver)
        return error("No short position on this driver") unless holding
        return error("You only have #{holding.quantity} shorted") if @quantity > holding.quantity

        pnl = (holding.entry_price - share_price) * @quantity
        new_cash = [wallet.cash + pnl, 0].max
        actual_pnl = new_cash - wallet.cash

        released_collateral = (holding.collateral.to_f / holding.quantity) * @quantity

        if @quantity == holding.quantity
          holding.update!(active: false, closed_race: @race, collateral: 0)
        else
          holding.update!(quantity: holding.quantity - @quantity, collateral: holding.collateral - released_collateral)
        end

        wallet.update!(cash: new_cash)
        log_transaction(kind: "short_close", price: share_price, amount: actual_pnl,
          note: "Closed short #{@quantity}x #{@driver.fullname} at #{share_price.round(1)} (P&L: #{actual_pnl >= 0 ? '+' : ''}#{actual_pnl.round(1)})")
        adjust_demand(@quantity)
      end
    end
  end
end
