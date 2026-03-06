class FantasyStockPortfoliosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_feature!
  before_action :set_portfolio, only: [:show, :market, :buy, :sell, :short_open, :short_close]
  before_action :set_next_race, only: [:show, :market, :buy, :sell, :short_open, :short_close]

  def new
    current_season = Season.sorted_by_year.first
    existing = current_user.fantasy_stock_portfolio_for(current_season)
    if existing
      redirect_to existing
      return
    end

    @season = current_season
    @starting_capital = compute_starting_capital
  end

  def create
    season = Season.sorted_by_year.first
    result = Fantasy::Stock::CreatePortfolio.new(user: current_user, season: season).call

    if result[:error]
      redirect_to new_fantasy_stock_portfolio_path, alert: result[:error]
    else
      redirect_to result[:portfolio], notice: "Stock portfolio created with #{result[:portfolio].cash.round(1)} cash."
    end
  end

  def show
    roster = current_user.fantasy_portfolio_for(@portfolio.season)
    if roster
      redirect_to fantasy_portfolio_path(roster, tab: "stocks")
      return
    end

    # Fallback for users with only a stock portfolio (no roster)
    @holdings = @portfolio.active_holdings.includes(driver: :countries).order(:direction, :entry_price)
    @transactions = @portfolio.transactions.order(created_at: :desc).limit(20)
    @can_trade = @next_race && @portfolio.can_trade?(@next_race)
    @snapshots = @portfolio.snapshots.joins(:race).order("races.date ASC")
    @value_delta = @portfolio.value_change_since_last_race
    @constructors_by_driver = constructors_for_drivers(@holdings.map(&:driver))
    @achievements = @portfolio.achievements.to_a
  end

  def market
    @drivers = Driver.joins(:season_drivers)
                     .where(season_drivers: { season_id: @portfolio.season_id })
                     .order(Arel.sql("COALESCE(drivers.elo_v2, 0) DESC"))
                     .includes(:countries)
    @can_trade = @next_race && @portfolio.can_trade?(@next_race)
    @constructors_by_driver = constructors_for_drivers(@drivers)
    @holdings_by_driver = @portfolio.active_holdings.group_by(&:driver_id)
    @elo_trends = elo_trends_for(@drivers.map(&:id))
  end

  def buy
    driver = Driver.find(params[:driver_id])
    quantity = (params[:quantity] || 1).to_i
    result = Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: driver, quantity: quantity, race: @next_race).call

    if result[:error]
      redirect_to market_fantasy_stock_portfolio_path(@portfolio), alert: result[:error]
    else
      redirect_to fantasy_stock_portfolio_path(@portfolio), notice: "Bought #{quantity}x #{driver.fullname}!"
    end
  end

  def sell
    driver = Driver.find(params[:driver_id])
    quantity = (params[:quantity] || 1).to_i
    result = Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: driver, quantity: quantity, race: @next_race).call

    if result[:error]
      redirect_to fantasy_stock_portfolio_path(@portfolio), alert: result[:error]
    else
      redirect_to fantasy_stock_portfolio_path(@portfolio), notice: "Sold #{quantity}x #{driver.fullname}!"
    end
  end

  def short_open
    driver = Driver.find(params[:driver_id])
    quantity = (params[:quantity] || 1).to_i
    result = Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: driver, quantity: quantity, race: @next_race).call

    if result[:error]
      redirect_to market_fantasy_stock_portfolio_path(@portfolio), alert: result[:error]
    else
      redirect_to fantasy_stock_portfolio_path(@portfolio), notice: "Shorted #{quantity}x #{driver.fullname}!"
    end
  end

  def short_close
    driver = Driver.find(params[:driver_id])
    quantity = (params[:quantity] || 1).to_i
    result = Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: driver, quantity: quantity, race: @next_race).call

    if result[:error]
      redirect_to fantasy_stock_portfolio_path(@portfolio), alert: result[:error]
    else
      redirect_to fantasy_stock_portfolio_path(@portfolio), notice: "Closed short on #{driver.fullname}!"
    end
  end

  def leaderboard
    @season = Season.sorted_by_year.first
    @entries = FantasyStockPortfolio.where(season: @season)
                 .includes(:user, :snapshots, holdings: :driver)
                 .sort_by { |p| -p.portfolio_value }
                 .map.with_index(1) { |p, i| { rank: i, portfolio: p, user: p.user, value: p.portfolio_value } }
  end

  private

  def require_feature!
    unless Setting.fantasy_stock_market?
      redirect_to root_path, alert: "Stock market is not available."
    end
  end

  def set_portfolio
    @portfolio = FantasyStockPortfolio.find(params[:id])
    authorize @portfolio
  end

  def set_next_race
    @next_race = @portfolio.season.next_race ||
                 Race.where("date >= ?", Date.current).order(:date).first
  end

  def compute_starting_capital
    season = Season.sorted_by_year.first
    avg_elo = Driver.where.not(elo_v2: nil)
                    .joins(:season_drivers)
                    .where(season_drivers: { season_id: season.id })
                    .average(:elo_v2) || 0
    (avg_elo * FantasyStockPortfolio::CAPITAL_MULTIPLIER).round(1)
  end

  def constructors_for_drivers(drivers)
    driver_ids = drivers.map(&:id)
    season = @portfolio&.season || Season.sorted_by_year.first

    entries = SeasonDriver.where(driver_id: driver_ids, season_id: season.id)
                          .includes(:constructor)
                          .index_by(&:driver_id)

    missing = driver_ids - entries.keys
    if missing.any?
      SeasonDriver.where(driver_id: missing)
                  .joins(:season).includes(:constructor)
                  .order("seasons.year DESC")
                  .each { |sd| entries[sd.driver_id] ||= sd }
    end

    entries.transform_values(&:constructor)
  end

  def elo_trends_for(driver_ids)
    results = RaceResult.where(driver_id: driver_ids)
                        .where.not(old_elo_v2: nil).where.not(new_elo_v2: nil)
                        .joins(:race)
                        .order("races.date DESC")
                        .select(:driver_id, :old_elo_v2, :new_elo_v2)

    results.group_by(&:driver_id).transform_values do |rrs|
      rrs.first(5).map { |rr| (rr.new_elo_v2 - rr.old_elo_v2).round(0) }
    end
  end
end
