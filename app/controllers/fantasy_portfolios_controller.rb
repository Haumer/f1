class FantasyPortfoliosController < ApplicationController
  include FantasyPortfolioData
  before_action :authenticate_user!, except: [:combined_leaderboard, :overview, :roster, :stocks, :leaderboard]
  before_action :set_portfolio, only: [:market, :buy, :buy_multiple, :sell, :buy_team]
  before_action :set_next_race, only: [:market, :buy, :buy_multiple, :sell, :buy_team]
  after_action :verify_authorized, only: [:buy, :sell, :buy_multiple, :buy_team, :market]

  # ═══════════════════════════════════════
  # Username-based pages
  # ═══════════════════════════════════════

  def overview
    load_user_and_season
    return if performed?

    load_portfolio_data
    load_stock_data
    @predictions = Prediction.where(user: @user)
                             .joins(race: :season)
                             .where(seasons: { year: @season.year })
                             .includes(race: [:circuit, :season])
                             .order("races.round DESC")
  end

  def roster
    load_user_and_season
    return if performed?

    unless @portfolio
      redirect_to fantasy_overview_path(@user.username), alert: "No roster portfolio found."
      return
    end

    @active_entries = @portfolio.active_roster_entries.includes(driver: [:countries])
    @snapshots = @portfolio.snapshots.joins(:race).order("races.date ASC")
    @value_delta = @portfolio.value_change_since_last_race
    @constructors_by_driver = constructors_for_drivers(@active_entries.map(&:driver))
    @achievements = @portfolio.achievements.order(created_at: :desc)

    if @is_owner
      @next_race = @portfolio.season.next_race || Race.where("date >= ?", Date.current).order(:date).first
      @can_trade = @next_race && @portfolio.can_trade?(@next_race)
      @transactions = @portfolio.transactions.order(created_at: :desc).limit(20)
      @current_support = ConstructorSupport.current_for(current_user, @portfolio.season)
      @can_change_support = ConstructorSupport.can_change?(current_user, @portfolio.season)
    end
  end

  def stocks
    load_user_and_season
    return if performed?

    unless @stock_portfolio
      redirect_to fantasy_overview_path(@user.username), alert: "No stock portfolio found."
      return
    end

    @stock_holdings = @stock_portfolio.active_holdings.includes(driver: :countries).order(:direction, :entry_price)
    @stock_snapshots = @stock_portfolio.snapshots.joins(:race).order("races.date ASC")
    @stock_value_delta = @stock_portfolio.value_change_since_last_race
    @stock_achievements = @stock_portfolio.achievements.to_a
    @stock_constructors = constructors_for_drivers(@stock_holdings.map(&:driver))
    @stock_total_dividends = @stock_portfolio.transactions.where(kind: "dividend").sum(:amount)

    if @is_owner
      @next_race = @stock_portfolio.season.next_race || Race.where("date >= ?", Date.current).order(:date).first
      @stock_can_trade = @next_race && @stock_portfolio.can_trade?(@next_race)
      @stock_transactions = @stock_portfolio.transactions.order(created_at: :desc).limit(20)
    end
  end

  # ═══════════════════════════════════════
  # Portfolio creation
  # ═══════════════════════════════════════

  def new
    current_season = Season.sorted_by_year.first
    existing = current_user.fantasy_portfolio_for(current_season)
    if existing
      redirect_to fantasy_overview_path(current_user.username)
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
      redirect_to fantasy_overview_path(current_user.username), notice: "Fantasy portfolio created! You have #{result[:portfolio].cash.round(0)} to spend."
    end
  end

  # ═══════════════════════════════════════
  # Market & trading (portfolio ID based)
  # ═══════════════════════════════════════

  def market
    season_driver_ids = SeasonDriver.where(season_id: @portfolio.season_id).select(:driver_id)
    @drivers = Driver.where(id: season_driver_ids)
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
      redirect_to fantasy_roster_path(current_user.username), notice: "#{driver.fullname} added to your roster!"
    end
  end

  def buy_multiple
    driver_ids = Array(params[:driver_ids]).map(&:to_i).uniq
    errors = []
    bought = []

    ActiveRecord::Base.transaction do
      driver_ids.each do |driver_id|
        driver = Driver.find(driver_id)
        result = Fantasy::BuyDriver.new(portfolio: @portfolio.reload, driver: driver, race: @next_race).call
        if result[:error]
          errors << "#{driver.fullname}: #{result[:error]}"
          raise ActiveRecord::Rollback
        else
          bought << driver.fullname
        end
      end
    end

    if errors.any?
      redirect_to market_fantasy_portfolio_path(@portfolio), alert: errors.join(". ")
    else
      check_roster_achievements(@portfolio)
      redirect_to fantasy_roster_path(current_user.username), notice: "#{bought.join(' & ')} added to your roster!"
    end
  end

  def sell
    driver = Driver.find(params[:driver_id])
    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: driver, race: @next_race).call

    if result[:error]
      redirect_to fantasy_roster_path(current_user.username), alert: result[:error]
    else
      check_roster_achievements(@portfolio)
      redirect_to fantasy_roster_path(current_user.username), notice: "Sold #{driver.fullname} for #{result[:net].round(0)} (fee: #{result[:fee].round(0)})"
    end
  end

  def buy_team
    result = Fantasy::BuyTeam.new(portfolio: @portfolio, race: @next_race).call

    if result[:error]
      redirect_to fantasy_roster_path(current_user.username), alert: result[:error]
    else
      check_roster_achievements(@portfolio)
      redirect_to fantasy_roster_path(current_user.username), notice: "New team purchased! You now have #{@portfolio.roster_slots} driver seats."
    end
  end

  # ═══════════════════════════════════════
  # Leaderboards
  # ═══════════════════════════════════════

  def leaderboard
    @season = Season.sorted_by_year.first
    @entries = Fantasy::Leaderboard.new(season: @season).call
    @roster_deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, @entries.map { |e| e[:portfolio].id })
    user_ids = @entries.map { |e| e[:portfolio].user_id }
    @supports_by_user = ConstructorSupport.where(user_id: user_ids, season: @season, active: true)
                          .includes(:constructor).index_by(&:user_id)
    @tab = "roster"
  end

  def combined_leaderboard
    @season = Season.sorted_by_year.first
    @tab = params[:tab] || "combined"

    @roster_entries = Fantasy::Leaderboard.new(season: @season).call
    @stock_entries = stock_leaderboard_entries

    combined = []
    @roster_entries.each do |e|
      p = e[:portfolio]
      roster_net = (e[:value] - p.starting_capital).round(2)
      combined << { user: p.user, roster_net: roster_net, stock_net: nil, roster_value: e[:value], stock_value: nil, total_starting: p.starting_capital }
    end
    @stock_entries.each do |e|
      p = e[:portfolio]
      stock_net = (e[:value] - p.starting_capital).round(2)
      existing = combined.find { |c| c[:user].id == p.user_id }
      if existing
        existing[:stock_net] = stock_net
        existing[:stock_value] = e[:value]
        existing[:total_starting] = (existing[:total_starting] || 0) + p.starting_capital
      else
        combined << { user: p.user, roster_net: nil, stock_net: stock_net, roster_value: nil, stock_value: e[:value], total_starting: p.starting_capital }
      end
    end

    combined.each do |c|
      c[:net_value] = (c[:roster_net] || 0) + (c[:stock_net] || 0)
      c[:total_value] = (c[:roster_value] || 0) + (c[:stock_value] || 0)
    end

    # Last race deltas
    roster_ids = @roster_entries.map { |e| e[:portfolio].id }
    stock_ids = @stock_entries.map { |e| e[:portfolio].id }
    @roster_deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, roster_ids)
    @stock_deltas = last_race_deltas(FantasyStockSnapshot, :fantasy_stock_portfolio_id, stock_ids)

    # Map deltas to users for combined view
    roster_by_user = @roster_entries.index_by { |e| e[:portfolio].user_id }
    stock_by_user = @stock_entries.index_by { |e| e[:portfolio].user_id }
    combined.each do |c|
      r_entry = roster_by_user[c[:user].id]
      s_entry = stock_by_user[c[:user].id]
      r_delta = r_entry ? (@roster_deltas[r_entry[:portfolio].id] || 0) : 0
      s_delta = s_entry ? (@stock_deltas[s_entry[:portfolio].id] || 0) : 0
      c[:last_race] = r_delta + s_delta
    end

    @combined_entries = combined.sort_by { |c| -c[:net_value] }

    user_ids = @combined_entries.map { |c| c[:user].id }
    @supports_by_user = ConstructorSupport.where(user_id: user_ids, season: @season, active: true)
                          .includes(:constructor).index_by(&:user_id)

    render "fantasy_portfolios/combined_leaderboard"
  end

  # ═══════════════════════════════════════
  # Profile visibility toggle
  # ═══════════════════════════════════════

  def toggle_public
    current_user.update!(public_profile: !current_user.public_profile?)
    status = current_user.public_profile? ? "public" : "private"
    redirect_back fallback_location: fantasy_overview_path(current_user.username),
                  notice: "Profile is now #{status}."
  end

end
