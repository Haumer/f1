module Fantasy
  class BuyTeam
    def initialize(portfolio:, race:)
      @portfolio = portfolio
      @race = race
    end

    def call
      return { error: "Transfer window is closed" } unless @portfolio.can_trade?(@race)

      cost = nil

      @portfolio.with_lock do
        return { error: "Already at maximum teams (#{FantasyPortfolio::MAX_TEAMS})" } unless @portfolio.can_buy_team?

        cost = @portfolio.team_cost
        available = @portfolio.available_cash
        return { error: "Not enough credits (need #{cost}, have #{available.round(0)})" } if available < cost

        @portfolio.update!(
          roster_slots: @portfolio.roster_slots + FantasyPortfolio::SLOTS_PER_TEAM,
          cash: @portfolio.cash - cost
        )

        @portfolio.transactions.create!(
          kind: "team_purchase",
          amount: -cost,
          note: "Purchased team #{@portfolio.teams_owned} — #{@portfolio.roster_slots} seats, #{@portfolio.max_swaps_per_race} swaps/race"
        )
      end

      { success: true, cost: cost }
    end
  end
end
