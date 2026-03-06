class FantasyPortfoliosController < ApplicationController
  before_action :authenticate_user!, except: [:combined_leaderboard]
  before_action :set_portfolio, only: [:show, :market, :buy, :buy_multiple, :sell, :buy_team]
  before_action :set_next_race, only: [:show, :market, :buy, :buy_multiple, :sell, :buy_team]

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
    season = Season.sorted_by_year.first
    result = Fantasy::CreatePortfolio.new(user: current_user, season: season).call

    if result[:error]
      redirect_to new_fantasy_portfolio_path, alert: result[:error]
    else
      check_roster_achievements(result[:portfolio])
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
    @current_support = ConstructorSupport.current_for(current_user, @portfolio.season)
    @can_change_support = ConstructorSupport.can_change?(current_user, @portfolio.season)

    # Stock portfolio (for unified view)
    @stock_portfolio = current_user.fantasy_stock_portfolio_for(@portfolio.season)
    if @stock_portfolio
      @stock_holdings = @stock_portfolio.active_holdings.includes(driver: :countries).order(:direction, :entry_price)
      @stock_transactions = @stock_portfolio.transactions.order(created_at: :desc).limit(20)
      @stock_can_trade = @next_race && @stock_portfolio.can_trade?(@next_race)
      @stock_snapshots = @stock_portfolio.snapshots.joins(:race).order("races.date ASC")
      @stock_achievements = @stock_portfolio.achievements.to_a
      @stock_value_delta = @stock_portfolio.value_change_since_last_race
      @stock_constructors = constructors_for_drivers(@stock_holdings.map(&:driver))
    end

    @tab = params[:tab] || "roster"
  end

  def market
    @drivers = Driver.joins(:season_drivers)
                     .where(season_drivers: { season_id: @portfolio.season_id })
                     .order(Arel.sql("COALESCE(drivers.elo_v2, 0) DESC"))
                     .includes(:countries)
    @active_driver_ids = @portfolio.active_roster_entries.pluck(:driver_id)
    @can_trade = @next_race && @portfolio.can_trade?(@next_race)
    @constructors_by_driver = constructors_for_drivers(@drivers)
    @elo_trends = elo_trends_for(@drivers.map(&:id))
  end

  def buy
    driver = Driver.find(params[:driver_id])
    result = Fantasy::BuyDriver.new(portfolio: @portfolio, driver: driver, race: @next_race).call

    if result[:error]
      redirect_to market_fantasy_portfolio_path(@portfolio), alert: result[:error]
    else
      check_roster_achievements(@portfolio)
      redirect_to fantasy_portfolio_path(@portfolio), notice: "#{driver.fullname} added to your roster!"
    end
  end

  def buy_multiple
    driver_ids = Array(params[:driver_ids]).map(&:to_i).uniq
    errors = []
    bought = []

    driver_ids.each do |driver_id|
      driver = Driver.find(driver_id)
      result = Fantasy::BuyDriver.new(portfolio: @portfolio.reload, driver: driver, race: @next_race).call
      if result[:error]
        errors << "#{driver.fullname}: #{result[:error]}"
      else
        bought << driver.fullname
      end
    end

    if errors.any?
      redirect_to market_fantasy_portfolio_path(@portfolio), alert: errors.join(". ")
    else
      check_roster_achievements(@portfolio)
      redirect_to fantasy_portfolio_path(@portfolio), notice: "#{bought.join(' & ')} added to your roster!"
    end
  end

  def sell
    driver = Driver.find(params[:driver_id])
    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: driver, race: @next_race).call

    if result[:error]
      redirect_to fantasy_portfolio_path(@portfolio), alert: result[:error]
    else
      check_roster_achievements(@portfolio)
      redirect_to fantasy_portfolio_path(@portfolio), notice: "Sold #{driver.fullname} for #{result[:net].round(0)} (fee: #{result[:fee].round(0)})"
    end
  end

  def buy_team
    result = Fantasy::BuyTeam.new(portfolio: @portfolio).call

    if result[:error]
      redirect_to fantasy_portfolio_path(@portfolio), alert: result[:error]
    else
      check_roster_achievements(@portfolio)
      redirect_to fantasy_portfolio_path(@portfolio), notice: "New team purchased! You now have #{@portfolio.roster_slots} driver seats."
    end
  end

  def leaderboard
    @season = Season.sorted_by_year.first
    @entries = Fantasy::Leaderboard.new(season: @season).call
    @tab = "roster"
  end

  def combined_leaderboard
    @season = Season.sorted_by_year.first
    @tab = params[:tab] || "combined"

    @roster_entries = Fantasy::Leaderboard.new(season: @season).call
    @stock_entries = stock_leaderboard_entries

    # Combined: roster = driver holdings, stocks = stock holdings, cash = leftover cash
    combined = []
    @roster_entries.each do |e|
      p = e[:portfolio]
      pct = p.starting_capital > 0 ? ((e[:value] - p.starting_capital) / p.starting_capital * 100) : 0
      driver_holdings = e[:value] - p.cash
      combined << { user: p.user, roster_holdings: driver_holdings, roster_pl_pct: pct, stock_holdings: nil, stock_pl_pct: nil, cash: p.cash }
    end
    @stock_entries.each do |e|
      p = e[:portfolio]
      pct = p.starting_capital > 0 ? ((e[:value] - p.starting_capital) / p.starting_capital * 100) : 0
      stock_holdings = e[:value] - p.cash
      existing = combined.find { |c| c[:user].id == p.user_id }
      if existing
        existing[:stock_holdings] = stock_holdings
        existing[:stock_pl_pct] = pct
        existing[:cash] = (existing[:cash] || 0) + p.cash
      else
        combined << { user: p.user, roster_holdings: nil, roster_pl_pct: nil, stock_holdings: stock_holdings, stock_pl_pct: pct, cash: p.cash }
      end
    end

    # Combined score = average of available P&L percentages
    combined.each do |c|
      pcts = [c[:roster_pl_pct], c[:stock_pl_pct]].compact
      c[:combined_pct] = pcts.any? ? (pcts.sum / pcts.size) : 0
      c[:total_value] = (c[:roster_holdings] || 0) + (c[:stock_holdings] || 0) + (c[:cash] || 0)
    end

    @combined_entries = combined.sort_by { |c| -c[:combined_pct] }

    # Preload constructor supports for leaderboard display
    user_ids = @combined_entries.map { |c| c[:user].id }
    @supports_by_user = ConstructorSupport.where(user_id: user_ids, season: @season, active: true)
                          .includes(:constructor).index_by(&:user_id)

    render "fantasy_portfolios/combined_leaderboard"
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
    season = Season.sorted_by_year.first
    avg_elo = Driver.where.not(elo_v2: nil)
                    .joins(:season_drivers)
                    .where(season_drivers: { season_id: season.id })
                    .average(:elo_v2) || 0
    (avg_elo * Fantasy::CreatePortfolio::CAPITAL_MULTIPLIER).round(0)
  end

  def check_roster_achievements(portfolio)
    Fantasy::CheckAchievements.new(portfolio: portfolio, race: nil).call
  rescue => e
    Rails.logger.error("Achievement check failed: #{e.message}")
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

  def stock_leaderboard_entries
    return [] unless Setting.fantasy_stock_market?
    FantasyStockPortfolio.where(season: @season)
      .includes(:user, :snapshots, holdings: :driver)
      .to_a
      .map { |p| { portfolio: p, value: p.portfolio_value } }
      .sort_by { |e| -e[:value] }
  end

  # Returns { driver_id => [+12, -5, +3, +8, -2] } (last 5 elo diffs, newest first)
  def elo_trends_for(driver_ids)
    results = RaceResult.where(driver_id: driver_ids)
                        .where.not(old_elo_v2: nil, new_elo_v2: nil)
                        .joins(:race)
                        .order("races.date DESC")
                        .select(:driver_id, :old_elo_v2, :new_elo_v2)

    results.group_by(&:driver_id).transform_values do |rrs|
      rrs.first(5).map { |rr| (rr.new_elo_v2 - rr.old_elo_v2).round(0) }
    end
  end
end
