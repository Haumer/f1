class FantasyStockAchievement < ApplicationRecord
  include AchievementModel
  belongs_to :fantasy_stock_portfolio
  validates :key, uniqueness: { scope: :fantasy_stock_portfolio_id }

  DEFINITIONS = {
    first_stock_trade:  { name: "First Trade",       description: "Made your first stock transaction",  icon: "fa-handshake",          tier: "bronze" },
    traded_5_races:     { name: "Active Trader",     description: "Traded in 5 different races",        icon: "fa-arrows-rotate",      tier: "silver" },
    traded_15_races:    { name: "Wall Street",       description: "Traded in 15+ races (60% of season)", icon: "fa-landmark",           tier: "gold" },
    first_long:         { name: "Bull Market",       description: "Opened your first long position",    icon: "fa-arrow-trend-up",     tier: "bronze" },
    first_short:        { name: "Bear Market",       description: "Opened your first short position",   icon: "fa-arrow-trend-down",   tier: "bronze" },
    max_positions:      { name: "Full Portfolio",    description: "Held the maximum number of positions", icon: "fa-briefcase",        tier: "silver" },
    first_stock_profit: { name: "In the Green",      description: "Trading P&L turned positive",         icon: "fa-arrow-trend-up",     tier: "bronze" },
    stock_pl_500:       { name: "In the Black",      description: "Earned 500+ trading P&L",             icon: "fa-sack-dollar",        tier: "bronze" },
    stock_pl_2k:        { name: "Sharp Trader",      description: "Earned 2,000+ trading P&L",           icon: "fa-coins",              tier: "silver" },
    stock_pl_5k:        { name: "Stock Mogul",       description: "Earned 5,000+ trading P&L",           icon: "fa-crown",              tier: "gold" },
    stock_pl_20k:       { name: "Wolf of Wall Street", description: "Earned 20,000+ trading P&L",        icon: "fa-money-bill-trend-up", tier: "legendary" },
    profitable_short:   { name: "Short Seller",      description: "Closed a short position in profit",   icon: "fa-circle-down",        tier: "silver" },
    first_dividend:     { name: "Dividend Day",      description: "Earned your first dividend payout",   icon: "fa-coins",              tier: "bronze" },
    stock_top_3:        { name: "Top Trader",        description: "Reached top 3 on the stock leaderboard", icon: "fa-ranking-star",     tier: "silver" },
    stock_top_1:        { name: "Market Champion",   description: "Reached #1 on the stock leaderboard", icon: "fa-flag-checkered",     tier: "gold" },
  }.freeze
end
