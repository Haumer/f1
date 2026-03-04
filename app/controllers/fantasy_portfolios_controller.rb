class FantasyPortfoliosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio, only: [:show, :market, :buy, :sell]
  before_action :set_next_race, only: [:show, :market, :buy, :sell]

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
    @active_entries = @portfolio.active_roster_entries.includes(:driver)
    @transactions = @portfolio.transactions.order(created_at: :desc).limit(20)
    @can_trade = @next_race && @portfolio.can_trade?(@next_race)
  end

  def market
    @drivers = Driver.where(active: true)
                     .where.not(elo_v2: nil)
                     .order(elo_v2: :desc)
                     .includes(:countries, season_drivers: :constructor)
    @active_driver_ids = @portfolio.active_roster_entries.pluck(:driver_id)
    @can_trade = @next_race && @portfolio.can_trade?(@next_race)
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

  def leaderboard
    @season = Season.sorted_by_year.first
    @entries = Fantasy::Leaderboard.new(season: @season).call
  end

  private

  def set_portfolio
    @portfolio = current_user.fantasy_portfolios.find(params[:id])
  end

  def set_next_race
    @next_race = @portfolio.season.next_race ||
                 Race.where("date >= ?", Date.current).order(:date).first
  end

  def compute_starting_capital
    avg_elo = Driver.where(active: true).average(:elo_v2) || 0
    (avg_elo * Fantasy::CreatePortfolio::CAPITAL_MULTIPLIER).round(0)
  end
end
