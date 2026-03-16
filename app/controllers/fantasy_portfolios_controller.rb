class FantasyPortfoliosController < ApplicationController
  include FantasyPortfolioData
  before_action :authenticate_user!, except: [:combined_leaderboard, :overview, :leaderboard]

  # ═══════════════════════════════════════
  # Username-based pages
  # ═══════════════════════════════════════

  def overview
    load_user_and_season
    return if performed?

    load_portfolio_data
    load_stock_data

    if @portfolio
      @achievements = @portfolio.achievements.order(created_at: :desc)
      if @is_owner
        @next_race = @portfolio.season.next_race || Race.where("date >= ?", Date.current).order(:date).first
        @can_trade = @next_race && @portfolio.can_trade?(@next_race)
        @current_support = ConstructorSupport.current_for(current_user, @portfolio.season)
        @can_change_support = ConstructorSupport.can_change?(current_user, @portfolio.season)
      end
    end

    # Stock detail data (inline on overview)
    if @stock_portfolio
      @stock_achievements = @stock_portfolio.achievements.to_a
      @stock_total_dividends = @stock_portfolio.transactions.where(kind: "dividend").sum(:amount)
      if @is_owner
        @next_race ||= @stock_portfolio.season.next_race || Race.where("date >= ?", Date.current).order(:date).first
        @stock_can_trade = @next_race && @stock_portfolio.can_trade?(@next_race)
        @stock_transactions = @stock_portfolio.transactions.order(created_at: :desc).limit(20)
      end
    end

    # Race picks — upcoming + past
    @race_picks = RacePick.where(user: @user)
                          .joins(race: :season)
                          .where(seasons: { year: @season.year })
                          .includes(race: [:circuit, :season])
                          .order("races.round DESC")

    @predictions = Prediction.where(user: @user)
                             .joins(race: :season)
                             .where(seasons: { year: @season.year })
                             .includes(race: [:circuit, :season])
                             .order("races.round DESC")
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
      redirect_to fantasy_overview_path(current_user.username), notice: "Portfolio created! You have #{result[:portfolio].cash.round(0)} to spend."
    end
  end

  # ═══════════════════════════════════════
  # Leaderboards
  # ═══════════════════════════════════════

  def leaderboard
    @season = Season.sorted_by_year.first
    @entries = Fantasy::Leaderboard.new(season: @season).call
    starting = Fantasy::CreatePortfolio::STARTING_CAPITAL
    roster_starts = @entries.each_with_object({}) { |e, h| h[e[:portfolio].id] = starting }
    @roster_deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, @entries.map { |e| e[:portfolio].id }, starting_values: roster_starts)
    user_ids = @entries.map { |e| e[:portfolio].user_id }
    @supports_by_user = ConstructorSupport.where(user_id: user_ids, season: @season, active: true)
                          .includes(:constructor).index_by(&:user_id)
  end

  def combined_leaderboard
    @season = Season.sorted_by_year.first
    @entries = Fantasy::Leaderboard.new(season: @season).call

    starting = Fantasy::CreatePortfolio::STARTING_CAPITAL
    portfolio_ids = @entries.map { |e| e[:portfolio].id }
    starts = portfolio_ids.each_with_object({}) { |id, h| h[id] = starting }
    @deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, portfolio_ids, starting_values: starts)

    user_ids = @entries.map { |e| e[:portfolio].user_id }
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
end
