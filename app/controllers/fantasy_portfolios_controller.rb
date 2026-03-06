class FantasyPortfoliosController < ApplicationController
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
      redirect_to fantasy_roster_path(current_user.username), notice: "#{driver.fullname} added to your roster!"
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
    result = Fantasy::BuyTeam.new(portfolio: @portfolio).call

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

    combined.each do |c|
      pcts = [c[:roster_pl_pct], c[:stock_pl_pct]].compact
      c[:combined_pct] = pcts.any? ? (pcts.sum / pcts.size) : 0
      c[:total_value] = (c[:roster_holdings] || 0) + (c[:stock_holdings] || 0) + (c[:cash] || 0)
    end

    @combined_entries = combined.sort_by { |c| -c[:combined_pct] }

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

  private

  def load_user_and_season
    @user = User.find_by!(username: params[:username])
    @season = Season.sorted_by_year.first
    @is_owner = current_user&.id == @user.id

    unless @is_owner || @user.public_profile?
      redirect_to combined_leaderboard_path, alert: "This profile is private."
      return
    end

    @portfolio = @user.fantasy_portfolio_for(@season)
    @stock_portfolio = @user.fantasy_stock_portfolio_for(@season)

    unless @portfolio || @stock_portfolio
      redirect_to combined_leaderboard_path, alert: "No fantasy portfolio found."
    end
  end

  def load_portfolio_data
    return unless @portfolio
    @active_entries = @portfolio.active_roster_entries.includes(driver: [:countries])
    @snapshots = @portfolio.snapshots.joins(:race).order("races.date ASC")
    @value_delta = @portfolio.value_change_since_last_race
    @constructors_by_driver = constructors_for_drivers(@active_entries.map(&:driver))
  end

  def load_stock_data
    return unless @stock_portfolio
    @stock_holdings = @stock_portfolio.active_holdings.includes(driver: :countries).order(:direction, :entry_price)
    @stock_snapshots = @stock_portfolio.snapshots.joins(:race).order("races.date ASC")
    @stock_value_delta = @stock_portfolio.value_change_since_last_race
    @stock_constructors = constructors_for_drivers(@stock_holdings.map(&:driver))
  end

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
    season = @portfolio&.season || @season || Season.sorted_by_year.first

    entries = SeasonDriver.where(driver_id: driver_ids, season_id: season.id)
                          .includes(:constructor)
                          .index_by(&:driver_id)

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
