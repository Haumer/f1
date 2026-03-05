class FantasyPortfoliosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio, only: [:show, :market, :buy, :sell, :buy_team]
  before_action :set_next_race, only: [:show, :market, :buy, :sell, :buy_team]

  def new
    current_season = Season.sorted_by_year.first
    existing = current_user.fantasy_portfolio_for(current_season)
    if existing
      redirect_to existing
      return
    end

    @season = current_season
    @starting_capital = compute_starting_capital
  end

  def create
    season = Season.find(params[:season_id])
    result = Fantasy::CreatePortfolio.new(user: current_user, season: season).call

    if result[:error]
      redirect_to new_fantasy_portfolio_path, alert: result[:error]
    else
      redirect_to result[:portfolio], notice: "Fantasy portfolio created! You have #{result[:portfolio].cash.round(0)} to spend."
    end
  end

  def show
    @active_entries = @portfolio.active_roster_entries.includes(driver: [:countries])
    @transactions = @portfolio.transactions.order(created_at: :desc).limit(20)
    @can_trade = @next_race && @portfolio.can_trade?(@next_race)
    @snapshots = @portfolio.snapshots.joins(:race).order("races.date ASC")
    @achievements = @portfolio.achievements.order(created_at: :desc)
    @value_delta = @portfolio.value_change_since_last_race
    @constructors_by_driver = constructors_for_drivers(@active_entries.map(&:driver))
  end

  def market
    @drivers = Driver.where(active: true)
                     .where.not(elo_v2: nil)
                     .order(elo_v2: :desc)
                     .includes(:countries)
    @active_driver_ids = @portfolio.active_roster_entries.pluck(:driver_id)
    @can_trade = @next_race && @portfolio.can_trade?(@next_race)
    @constructors_by_driver = constructors_for_drivers(@drivers)
  end

  def buy
    driver = Driver.find(params[:driver_id])
    result = Fantasy::BuyDriver.new(portfolio: @portfolio, driver: driver, race: @next_race).call

    if result[:error]
      redirect_to market_fantasy_portfolio_path(@portfolio), alert: result[:error]
    else
      redirect_to fantasy_portfolio_path(@portfolio), notice: "#{driver.fullname} added to your roster!"
    end
  end

  def sell
    driver = Driver.find(params[:driver_id])
    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: driver, race: @next_race).call

    if result[:error]
      redirect_to fantasy_portfolio_path(@portfolio), alert: result[:error]
    else
      redirect_to fantasy_portfolio_path(@portfolio), notice: "Sold #{driver.fullname} for #{result[:net].round(0)} (fee: #{result[:fee].round(0)})"
    end
  end

  def buy_team
    result = Fantasy::BuyTeam.new(portfolio: @portfolio).call

    if result[:error]
      redirect_to fantasy_portfolio_path(@portfolio), alert: result[:error]
    else
      redirect_to fantasy_portfolio_path(@portfolio), notice: "New team purchased! You now have #{@portfolio.roster_slots} driver seats."
    end
  end

  def leaderboard
    @season = Season.sorted_by_year.first
    @entries = Fantasy::Leaderboard.new(season: @season).call
  end

  private

  def set_portfolio
    @portfolio = FantasyPortfolio.find(params[:id])
    authorize @portfolio
  end

  def set_next_race
    @next_race = @portfolio.season.next_race ||
                 Race.where("date >= ?", Date.current).order(:date).first
  end

  def compute_starting_capital
    avg_elo = Driver.where(active: true).average(:elo_v2) || 0
    (avg_elo * Fantasy::CreatePortfolio::CAPITAL_MULTIPLIER).round(0)
  end

  def constructors_for_drivers(drivers)
    driver_ids = drivers.map(&:id)
    season = @portfolio&.season || Season.sorted_by_year.first

    # First try the portfolio's season
    entries = SeasonDriver.where(driver_id: driver_ids, season_id: season.id)
                          .includes(:constructor)
                          .index_by(&:driver_id)

    # For any drivers not found, fall back to latest season by year
    missing = driver_ids - entries.keys
    if missing.any?
      fallbacks = SeasonDriver.where(driver_id: missing)
                              .joins(:season)
                              .includes(:constructor)
                              .order("seasons.year DESC")
      fallbacks.each do |sd|
        entries[sd.driver_id] ||= sd
      end
    end

    entries.transform_values(&:constructor)
  end
end
