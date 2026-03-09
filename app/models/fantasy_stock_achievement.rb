class FantasyStockAchievement < ApplicationRecord
  include AchievementModel
  belongs_to :fantasy_stock_portfolio
  validates :key, uniqueness: { scope: :fantasy_stock_portfolio_id }

  DEFINITIONS = {
    first_stock_trade:     { name: "First Trade", description: "Made your first stock transaction", icon: "fa-handshake", tier: "bronze" },
    five_stock_trades:     { name: "Day Trader", description: "Completed 5 stock trades", icon: "fa-arrows-rotate", tier: "silver" },
    ten_stock_trades:      { name: "Wall Street", description: "Completed 10 stock trades", icon: "fa-landmark", tier: "gold" },
    first_long:            { name: "Bull Market", description: "Opened your first long position", icon: "fa-arrow-trend-up", tier: "bronze" },
    first_short:           { name: "Bear Market", description: "Opened your first short position", icon: "fa-arrow-trend-down", tier: "bronze" },
    max_positions:         { name: "Full Portfolio", description: "Held the maximum number of positions", icon: "fa-briefcase", tier: "silver" },
    first_stock_profit:    { name: "In the Green", description: "Portfolio value exceeded starting capital", icon: "fa-arrow-trend-up", tier: "bronze" },
    stock_profit_500:      { name: "Big Returns", description: "Earned 500+ profit from stocks", icon: "fa-sack-dollar", tier: "silver" },
    stock_profit_1000:     { name: "Stock Mogul", description: "Earned 1000+ profit from stocks", icon: "fa-crown", tier: "gold" },
    profitable_short:      { name: "Short Seller", description: "Closed a short position in profit", icon: "fa-circle-down", tier: "silver" },
    first_dividend:        { name: "Dividend Day", description: "Earned your first dividend payout", icon: "fa-coins", tier: "bronze" },
    stock_top_3:           { name: "Top Trader", description: "Reached top 3 on the stock leaderboard", icon: "fa-ranking-star", tier: "silver" },
    stock_top_1:           { name: "Market Champion", description: "Reached #1 on the stock leaderboard", icon: "fa-flag-checkered", tier: "gold" },
  }.freeze
end
