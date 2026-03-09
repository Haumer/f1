module Fantasy
  module Stock
    class SellShares < BaseTrade
      private

      def execute
        holding = @portfolio.active_longs.find_by(driver: @driver)
        return error("You don't hold this driver") unless holding
        return error("You only hold #{holding.quantity} shares") if @quantity > holding.quantity

        total = share_price * @quantity

        if @quantity == holding.quantity
          holding.update!(active: false, closed_race: @race)
        else
          holding.update!(quantity: holding.quantity - @quantity)
        end

        wallet.update!(cash: wallet.cash + total)
        log_transaction(kind: "sell", price: share_price, amount: total,
          note: "Sold #{@quantity}x #{@driver.fullname} at #{share_price.round(1)}")
        adjust_demand(-@quantity)
      end
    end
  end
end
