class FantasyAchievement < ApplicationRecord
  include AchievementModel
  belongs_to :fantasy_portfolio
  validates :key, uniqueness: { scope: :fantasy_portfolio_id }

  DEFINITIONS = {
    first_trade:       { name: "First Trade", description: "Made your first driver transaction", icon: "fa-handshake", tier: "bronze" },
    five_trades:       { name: "Dealmaker", description: "Completed 5 trades", icon: "fa-arrows-rotate", tier: "silver" },
    ten_trades:        { name: "Market Mover", description: "Completed 10 trades", icon: "fa-chart-line", tier: "gold" },
    first_profit:      { name: "In the Money", description: "Portfolio value exceeded starting capital", icon: "fa-arrow-trend-up", tier: "bronze" },
    profit_500:        { name: "Big Gains", description: "Earned 500+ profit", icon: "fa-sack-dollar", tier: "silver" },
    profit_1000:       { name: "Portfolio King", description: "Earned 1000+ profit", icon: "fa-crown", tier: "gold" },
    all_time_high:     { name: "New Heights", description: "Portfolio hit a new all-time high", icon: "fa-mountain-sun", tier: "bronze" },
    streak_3:          { name: "Hot Streak", description: "Portfolio value increased 3 races in a row", icon: "fa-fire", tier: "silver" },
    driver_won:        { name: "Winner's Circle", description: "A driver on your roster won a race", icon: "fa-trophy", tier: "silver" },
    driver_podium:     { name: "Podium Pick", description: "A driver on your roster finished on the podium", icon: "fa-medal", tier: "bronze" },
    driver_elo_surge:  { name: "Elo Rocket", description: "A rostered driver gained 40+ Elo in one race", icon: "fa-rocket", tier: "gold" },
    second_team:       { name: "Team Expansion", description: "Purchased your second team", icon: "fa-users", tier: "bronze" },
    third_team:        { name: "Racing Empire", description: "Own all 3 teams", icon: "fa-building", tier: "gold" },
    top_3:             { name: "Podium Finish", description: "Reached top 3 on the leaderboard", icon: "fa-ranking-star", tier: "silver" },
    top_1:             { name: "Champion", description: "Reached #1 on the leaderboard", icon: "fa-flag-checkered", tier: "gold" },
    early_adopter:     { name: "Early Adopter", description: "Created a portfolio before the first race", icon: "fa-seedling", tier: "bronze" },
  }.freeze
end
