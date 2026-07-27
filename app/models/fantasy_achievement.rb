class FantasyAchievement < ApplicationRecord
  include AchievementModel
  belongs_to :fantasy_portfolio
  validates :key, uniqueness: { scope: :fantasy_portfolio_id }

  DEFINITIONS = {
    first_profit:   { name: "In the Money",   description: "Portfolio value exceeded starting capital",       icon: "fa-arrow-trend-up", tier: "bronze" },
    profit_1x:      { name: "Doubled Up",     description: "Earned 10,000+ profit (1× starting capital)",     icon: "fa-sack-dollar",    tier: "bronze" },
    profit_2x:      { name: "Outperformer",   description: "Earned 20,000+ profit (2× starting capital)",     icon: "fa-coins",          tier: "silver" },
    profit_4x:      { name: "Portfolio King", description: "Earned 40,000+ profit (4× starting capital)",     icon: "fa-crown",          tier: "gold" },
    profit_10x:     { name: "Moonshot",       description: "Earned 100,000+ profit (10× starting capital)",   icon: "fa-rocket",         tier: "legendary" },
    all_time_high:  { name: "New Heights",    description: "Portfolio hit a new all-time high",               icon: "fa-mountain-sun",   tier: "bronze" },
    streak_3:       { name: "Hot Streak",     description: "Portfolio value increased 3 races in a row",      icon: "fa-fire",           tier: "silver" },
    top_3:          { name: "Podium Finish",  description: "Reached top 3 on the leaderboard",                icon: "fa-ranking-star",   tier: "silver" },
    top_1:          { name: "Champion",       description: "Reached #1 on the leaderboard",                   icon: "fa-flag-checkered", tier: "gold" },
    early_adopter:  { name: "Early Adopter",  description: "Created a portfolio before the first race",       icon: "fa-seedling",       tier: "bronze" },
  }.freeze
end
