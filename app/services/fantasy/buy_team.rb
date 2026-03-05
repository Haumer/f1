module Fantasy
  class BuyTeam
    def initialize(portfolio:)
      @portfolio = portfolio
    end

    def call
      return { error: "Already at maximum teams (#{FantasyPortfolio::MAX_TEAMS})" } unless @portfolio.can_buy_team?

      cost = @portfolio.team_cost
      return { error: "Not enough cash (need #{cost}, have #{@portfolio.cash.round(0)})" } if @portfolio.cash < cost

      ActiveRecord::Base.transaction do
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
