class FantasyStockPortfolio < ApplicationRecord
  include PortfolioCommon

  belongs_to :user
  belongs_to :season

  has_many :holdings, class_name: "FantasyStockHolding", dependent: :destroy
  has_many :transactions, class_name: "FantasyStockTransaction", dependent: :destroy
  has_many :snapshots, class_name: "FantasyStockSnapshot", dependent: :destroy
  has_many :achievements, class_name: "FantasyStockAchievement", dependent: :destroy

  validates :user_id, uniqueness: { scope: :season_id }
  validates :starting_capital, presence: true

  PRICE_DIVISOR = 10.0
  MAX_POSITIONS = 12
  COLLATERAL_RATIO = 0.5 # 50% margin requirement for shorts

  # Unified cash: stock portfolio uses roster portfolio as its wallet
  def wallet
    @wallet ||= FantasyPortfolio.find_by(user_id: user_id, season_id: season_id)
  end

  def active_holdings
    holdings.where(active: true)
  end

  def active_longs
    active_holdings.where(direction: "long")
  end

  def active_shorts
    active_holdings.where(direction: "short")
  end

  def position_count
    active_holdings.count
  end

  def positions_full?
    position_count >= MAX_POSITIONS
  end

  def share_price(driver)
    Fantasy::Pricing.stock_price_for(driver, season)
  end

  # Seed the per-instance holdings cache so a controller's already-preloaded
  # holdings array is reused by positions_value / total_invested /
  # total_collateral. Without seeding, those methods stay stateless and re-query
  # so settlement/trade flows that mutate holdings mid-request stay correct.
  def prime_active_holdings(holdings)
    @primed_active_holdings = holdings.to_a
  end

  # Positions-only value (no cash — cash lives in the wallet/roster portfolio)
  # Pass `prices_by_driver_id` to skip per-holding price lookups (used by
  # the leaderboard, which precomputes one bulk price map per season).
  def positions_value(prices_by_driver_id = nil)
    active = resolved_active_holdings
    price = ->(h) { prices_by_driver_id ? prices_by_driver_id[h.driver_id] : share_price(h.driver) }
    longs_value = active.select { |h| h.direction == "long" }.sum { |h| price.call(h) * h.quantity }
    shorts_pnl = active.select { |h| h.direction == "short" }.sum { |h| (h.entry_price - price.call(h)) * h.quantity }
    longs_value + shorts_pnl
  end

  # Total invested = sum of what was spent opening positions
  def total_invested
    resolved_active_holdings.select { |h| h.direction == "long" }.sum { |h| h.entry_price * h.quantity }
  end

  # Stock P&L = current positions value - total invested
  def profit_loss(prices_by_driver_id = nil)
    (positions_value(prices_by_driver_id) - total_invested).round(2)
  end

  # For backward compat — portfolio_value now means positions only
  def portfolio_value(prices_by_driver_id = nil)
    positions_value(prices_by_driver_id)
  end

  def can_trade?(race)
    return false unless race
    cutoff = race.starts_at || race.date&.beginning_of_day
    return false unless cutoff
    (cutoff - 1.minute) > Time.current
  end

  def total_collateral
    if @primed_active_holdings
      @primed_active_holdings.select { |h| h.direction == "short" }.sum { |h| h.collateral || 0 }
    else
      active_shorts.sum(:collateral)
    end
  end

  def available_cash
    (wallet&.cash || 0) - total_collateral
  end

  private

  def resolved_active_holdings
    return @primed_active_holdings if @primed_active_holdings
    holdings.loaded? ? holdings.select(&:active) : active_holdings.includes(:driver).to_a
  end
end
