module Fantasy
  module Stock
    class SellShares
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
          holding = @portfolio.active_longs.find_by(driver: @driver)
          return { error: "You don't hold this driver" } unless holding
          return { error: "You only hold #{holding.quantity} shares" } if @quantity > holding.quantity

          price = @portfolio.share_price(@driver)
          total = price * @quantity

          if @quantity == holding.quantity
            holding.update!(active: false, closed_race: @race)
          else
            holding.update!(quantity: holding.quantity - @quantity)
          end

          @portfolio.update!(cash: @portfolio.cash + total)

          @portfolio.transactions.create!(
            kind: "sell",
            driver: @driver,
            race: @race,
            quantity: @quantity,
            price: price,
            amount: total,
            note: "Sold #{@quantity}x #{@driver.fullname} at #{price.round(1)}"
          )
        end

        { success: true }
      end
    end
  end
end
