module Fantasy
  class SellDriver
    SELL_FEE = 0.01 # 1%

    def initialize(portfolio:, driver:, race:)
      @portfolio = portfolio
      @driver = driver
      @race = race
    end

    def call
      return { error: "Transfer window is closed" } unless @portfolio.can_trade?(@race)

      entry = @portfolio.active_roster_entries.find_by(driver_id: @driver.id)
      return { error: "Driver is not on your roster" } unless entry
      return { error: "Must hold driver for at least 1 race" } if @portfolio.held_races_for(@driver) < 1

      sell_price = @driver.elo_v2 || 0
      fee = (sell_price * SELL_FEE).round(1)
      net = sell_price - fee

      ActiveRecord::Base.transaction do
        entry.update!(
          active: false,
          sold_at_elo: sell_price,
          sold_race: @race
        )

        @portfolio.update!(cash: @portfolio.cash + net)

        @portfolio.transactions.create!(
          kind: "sell",
          amount: net,
          driver: @driver,
          race: @race,
          note: "Sold #{@driver.fullname} at #{sell_price.round(0)} (fee: #{fee.round(0)})"
        )
      end

      { success: true, net: net, fee: fee }
    end
  end
end
