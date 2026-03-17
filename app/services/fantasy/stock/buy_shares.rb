module Fantasy
  module Stock
    class BuyShares < BaseTrade
      private

      def execute
        existing = @portfolio.active_longs.find_by(driver: @driver)
        return error("Too many positions (max #{FantasyStockPortfolio::MAX_POSITIONS})") if !existing && @portfolio.positions_full?

        total_cost = share_price * @quantity
        return error("Not enough credits (need #{total_cost.round(1)}, have #{@portfolio.available_cash.round(1)})") if @portfolio.available_cash < total_cost

        if existing
          new_qty = existing.quantity + @quantity
          new_avg = ((existing.entry_price * existing.quantity) + (share_price * @quantity)) / new_qty
          existing.update!(quantity: new_qty, entry_price: new_avg)
        else
          @portfolio.holdings.create!(
            driver: @driver, quantity: @quantity, direction: "long",
            entry_price: share_price, opened_race: @race, active: true
          )
        end

        wallet.update!(cash: wallet.cash - total_cost)
        log_transaction(kind: "buy", price: share_price, amount: -total_cost,
          note: "Bought #{@quantity}x #{@driver.fullname} at #{share_price.round(1)}")
        adjust_demand(@quantity)
      end
    end
  end
end
