module Fantasy
  module Stock
    class BuyShares
      def initialize(portfolio:, driver:, quantity:, race:)
        @portfolio = portfolio
        @driver = driver
        @quantity = quantity.to_i
        @race = race
      end

      def call
        return { error: "Transfer window is closed" } unless @portfolio.can_trade?(@race)
        return { error: "Invalid quantity" } unless @quantity > 0

        existing = @portfolio.active_longs.find_by(driver: @driver)
        return { error: "Too many positions (max #{FantasyStockPortfolio::MAX_POSITIONS})" } if !existing && @portfolio.positions_full?

        price = @portfolio.share_price(@driver)
        total_cost = price * @quantity

        return { error: "Not enough cash (need #{total_cost.round(1)}, have #{@portfolio.available_cash.round(1)})" } if @portfolio.available_cash < total_cost

        ActiveRecord::Base.transaction do
          if existing
            new_qty = existing.quantity + @quantity
            new_avg = ((existing.entry_price * existing.quantity) + (price * @quantity)) / new_qty
            existing.update!(quantity: new_qty, entry_price: new_avg)
          else
            @portfolio.holdings.create!(
              driver: @driver,
              quantity: @quantity,
              direction: "long",
              entry_price: price,
              opened_race: @race,
              active: true
            )
          end

          @portfolio.update!(cash: @portfolio.cash - total_cost)

          @portfolio.transactions.create!(
            kind: "buy",
            driver: @driver,
            race: @race,
            quantity: @quantity,
            price: price,
            amount: -total_cost,
            note: "Bought #{@quantity}x #{@driver.fullname} at #{price.round(1)}"
          )
        end

        { success: true }
      end
    end
  end
end
