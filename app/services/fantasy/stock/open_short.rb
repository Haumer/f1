module Fantasy
  module Stock
    class OpenShort
      def initialize(portfolio:, driver:, quantity:, race:)
        @portfolio = portfolio
        @driver = driver
        @quantity = quantity.to_i
        @race = race
      end

      def call
        return { error: "Transfer window is closed" } unless @portfolio.can_trade?(@race)
        return { error: "Invalid quantity" } unless @quantity > 0

        existing = @portfolio.active_shorts.find_by(driver: @driver)
        return { error: "Too many positions (max #{FantasyStockPortfolio::MAX_POSITIONS})" } if !existing && @portfolio.positions_full?

        price = @portfolio.share_price(@driver)
        collateral_needed = price * @quantity

        return { error: "Not enough cash for collateral (need #{collateral_needed.round(1)}, have #{@portfolio.available_cash.round(1)})" } if @portfolio.available_cash < collateral_needed

        ActiveRecord::Base.transaction do
          if existing
            new_qty = existing.quantity + @quantity
            new_avg = ((existing.entry_price * existing.quantity) + (price * @quantity)) / new_qty
            existing.update!(
              quantity: new_qty,
              entry_price: new_avg,
              collateral: existing.collateral + collateral_needed
            )
          else
            @portfolio.holdings.create!(
              driver: @driver,
              quantity: @quantity,
              direction: "short",
              entry_price: price,
              collateral: collateral_needed,
              opened_race: @race,
              active: true
            )
          end

          # Collateral is locked but stays in cash (just tracked)
          @portfolio.transactions.create!(
            kind: "short_open",
            driver: @driver,
            race: @race,
            quantity: @quantity,
            price: price,
            amount: 0, # No cash movement — collateral is locked
            note: "Shorted #{@quantity}x #{@driver.fullname} at #{price.round(1)} (#{collateral_needed.round(1)} collateral locked)"
          )
        end

        { success: true }
      end
    end
  end
end
