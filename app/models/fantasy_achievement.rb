class FantasyAchievement < ApplicationRecord
  include AchievementModel
  belongs_to :fantasy_portfolio
  validates :key, uniqueness: { scope: :fantasy_portfolio_id }

  DEFINITIONS = {
    first_profit:      { name: "In the Money", description: "Portfolio value exceeded starting capital", icon: "fa-arrow-trend-up", tier: "bronze" },
    profit_500:        { name: "Big Gains", description: "Earned 500+ profit", icon: "fa-sack-dollar", tier: "silver" },
    profit_1000:       { name: "Portfolio King", description: "Earned 1000+ profit", icon: "fa-crown", tier: "gold" },
    all_time_high:     { name: "New Heights", description: "Portfolio hit a new all-time high", icon: "fa-mountain-sun", tier: "bronze" },
    streak_3:          { name: "Hot Streak", description: "Portfolio value increased 3 races in a row", icon: "fa-fire", tier: "silver" },
    top_3:             { name: "Podium Finish", description: "Reached top 3 on the leaderboard", icon: "fa-ranking-star", tier: "silver" },
    top_1:             { name: "Champion", description: "Reached #1 on the leaderboard", icon: "fa-flag-checkered", tier: "gold" },
    early_adopter:     { name: "Early Adopter", description: "Created a portfolio before the first race", icon: "fa-seedling", tier: "bronze" },
  }.freeze
end
