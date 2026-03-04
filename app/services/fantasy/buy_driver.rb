module Fantasy
  class BuyDriver
    def initialize(portfolio:, driver:, race:)
      @portfolio = portfolio
      @driver = driver
      @race = race
    end

    def call
      return { error: "Transfer window is closed" } unless @portfolio.can_trade?(@race)
      return { error: "Driver is already on your roster" } if @portfolio.has_driver?(@driver)
      return { error: "Roster is full (max 2 drivers)" } if @portfolio.roster_full?

      price = @driver.elo_v2
      return { error: "Not enough cash (need #{price.round(0)}, have #{@portfolio.cash.round(0)})" } if @portfolio.cash < price

      ActiveRecord::Base.transaction do
        @portfolio.roster_entries.create!(
          driver: @driver,
          bought_at_elo: price,
          bought_race: @race,
          active: true
        )

        @portfolio.update!(cash: @portfolio.cash - price)

        @portfolio.transactions.create!(
          kind: "buy",
          amount: -price,
          driver: @driver,
          race: @race,
          note: "Bought #{@driver.fullname} at #{price.round(0)}"
        )
      end

      { success: true }
    end
  end
end
