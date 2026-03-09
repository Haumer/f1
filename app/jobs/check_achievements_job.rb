class CheckAchievementsJob < ApplicationJob
  queue_as :default

  def perform(portfolio_type:, portfolio_id:, race_id: nil)
    case portfolio_type
    when "roster"
      portfolio = FantasyPortfolio.find_by(id: portfolio_id)
      return unless portfolio
      race = race_id ? Race.find_by(id: race_id) : nil
      Fantasy::CheckAchievements.new(portfolio: portfolio, race: race).call
    when "stock"
      portfolio = FantasyStockPortfolio.find_by(id: portfolio_id)
      return unless portfolio
      race = race_id ? Race.find_by(id: race_id) : nil
      Fantasy::Stock::CheckAchievements.new(portfolio: portfolio, race: race).call
    end
  end
end
