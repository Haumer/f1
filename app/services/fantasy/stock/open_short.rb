module Fantasy
  module Stock
    class OpenShort < BaseTrade
      private

      def execute
        existing = @portfolio.active_shorts.find_by(driver: @driver)
        return error("Too many positions (max #{FantasyStockPortfolio::MAX_POSITIONS})") if !existing && @portfolio.positions_full?

        collateral_needed = share_price * @quantity * FantasyStockPortfolio::COLLATERAL_RATIO
        return error("Not enough credits for collateral (need #{collateral_needed.round(1)}, have #{@portfolio.available_cash.round(1)})") if @portfolio.available_cash < collateral_needed

        if existing
          new_qty = existing.quantity + @quantity
          new_avg = ((existing.entry_price * existing.quantity) + (share_price * @quantity)) / new_qty
          existing.update!(quantity: new_qty, entry_price: new_avg, collateral: existing.collateral + collateral_needed)
        else
          @portfolio.holdings.create!(
            driver: @driver, quantity: @quantity, direction: "short",
            entry_price: share_price, collateral: collateral_needed,
            opened_race: @race, active: true
          )
        end

        log_transaction(kind: "short_open", price: share_price, amount: 0,
          note: "Shorted #{@quantity}x #{@driver.fullname} at #{share_price.round(1)} (#{collateral_needed.round(1)} collateral locked)")
        adjust_demand(-@quantity)
      end
    end
  end
end
