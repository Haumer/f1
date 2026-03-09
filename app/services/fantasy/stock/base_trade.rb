module Fantasy
  module Stock
    class BaseTrade
      def initialize(portfolio:, driver:, quantity:, race:)
        @portfolio = portfolio
        @driver = driver
        @quantity = quantity.to_i
        @race = race
      end

      def call
        return { error: "Transfer window is closed" } unless @portfolio.can_trade?(@race)
        return { error: "Invalid quantity" } unless @quantity > 0

        result = nil
        @portfolio.with_lock do
          result = execute
        end
        result.is_a?(Hash) && result[:error] ? result : { success: true }
      end

      private

      def execute
        raise NotImplementedError
      end

      def share_price
        @share_price ||= @portfolio.share_price(@driver)
      end

      def wallet
        @wallet ||= begin
          w = @portfolio.wallet
          w.lock!
          w
        end
      end

      def log_transaction(kind:, price:, amount:, note:)
        @portfolio.transactions.create!(
          kind: kind, driver: @driver, race: @race,
          quantity: @quantity, price: price, amount: amount, note: note
        )
      end

      def adjust_demand(delta)
        SeasonDriver.adjust_demand!(@driver.id, @portfolio.season_id, delta)
      end

      def error(msg)
        { error: msg }
      end
    end
  end
end
