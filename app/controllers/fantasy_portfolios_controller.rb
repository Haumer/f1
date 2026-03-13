class FantasyPortfoliosController < ApplicationController
  include FantasyPortfolioData
  before_action :authenticate_user!, except: [:combined_leaderboard, :overview, :roster, :stocks, :leaderboard]
  before_action :set_portfolio, only: [:market, :buy, :buy_multiple, :sell, :buy_team, :unified_trade]
  before_action :set_next_race, only: [:market, :buy, :buy_multiple, :sell, :buy_team, :unified_trade]
  after_action :verify_authorized, only: [:buy, :sell, :buy_multiple, :buy_team, :market, :unified_trade]

  # ═══════════════════════════════════════
  # Username-based pages
  # ═══════════════════════════════════════

  def overview
    load_user_and_season
    return if performed?

    load_portfolio_data
    load_stock_data

    # Roster detail data (inline on overview)
    if @portfolio
      @achievements = @portfolio.achievements.order(created_at: :desc)
      if @is_owner
        @next_race = @portfolio.season.next_race || Race.where("date >= ?", Date.current).order(:date).first
        @can_trade = @next_race && @portfolio.can_trade?(@next_race)
        @transactions = @portfolio.transactions.order(created_at: :desc).limit(20)
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

  def roster
    redirect_to fantasy_overview_path(params[:username])
  end

  def stocks
    redirect_to fantasy_overview_path(params[:username])
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

    # Stock data for unified market
    @stock_portfolio = current_user.fantasy_stock_portfolio_for(@portfolio.season)
    if @stock_portfolio
      @stock_can_trade = @next_race && @stock_portfolio.can_trade?(@next_race)
      @holdings_by_driver = @stock_portfolio.active_holdings.group_by(&:driver_id)
    end
  end

  def buy
    driver = Driver.find(params[:driver_id])
    result = Fantasy::BuyDriver.new(portfolio: @portfolio, driver: driver, race: @next_race).call
    trade_redirect(result, "#{driver.fullname} added to your roster!")
  end

  def buy_multiple
    driver_ids = Array(params[:driver_ids]).map(&:to_i).uniq
    errors, bought = batch_roster_buys(driver_ids)
    trade_redirect(errors.any? ? { error: errors.join(". ") } : {}, "#{bought.join(' & ')} added to your roster!")
  end

  def unified_trade
    roster_ids = Array(params[:roster_driver_ids]).map(&:to_i).uniq.reject(&:zero?)
    stock_orders = Array(params[:stock_orders])
    errors, bought_roster, bought_stock = execute_unified_trade(roster_ids, stock_orders)

    parts = []
    parts << "Roster: #{bought_roster.join(' & ')}" if bought_roster.any?
    parts << "Stocks: #{bought_stock.join(', ')}" if bought_stock.any?
    trade_redirect(errors.any? ? { error: errors.join(". ") } : {}, parts.join(" | "))
  end

  def sell
    driver = Driver.find(params[:driver_id])
    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: driver, race: @next_race).call
    trade_redirect(result, "Sold #{driver.fullname} for #{result[:net]&.round(0)} (fee: #{result[:fee]&.round(0)})", to: fantasy_overview_path(current_user.username))
  end

  def buy_team
    result = Fantasy::BuyTeam.new(portfolio: @portfolio, race: @next_race).call
    trade_redirect(result, "New team purchased! You now have #{@portfolio.roster_slots} driver seats.", to: fantasy_overview_path(current_user.username))
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

    @combined_entries = build_combined_entries
    compute_combined_deltas

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

  def trade_redirect(result, success_msg, to: nil)
    if result[:error]
      redirect_to(to || market_fantasy_portfolio_path(@portfolio), alert: result[:error])
    else
      check_roster_achievements(@portfolio)
      auto_create_stock_portfolio_if_ready
      redirect_to(to || fantasy_overview_path(current_user.username), notice: success_msg)
    end
  end

  def batch_roster_buys(driver_ids)
    errors = []
    bought = []
    ActiveRecord::Base.transaction do
      driver_ids.each do |driver_id|
        driver = Driver.find(driver_id)
        result = Fantasy::BuyDriver.new(portfolio: @portfolio.reload, driver: driver, race: @next_race).call
        if result[:error]
          errors << "#{driver.fullname}: #{result[:error]}"
          raise ActiveRecord::Rollback
        end
        bought << driver.fullname
      end
    end
    [errors, bought]
  end

  def execute_unified_trade(roster_ids, stock_orders)
    errors = []
    bought_roster = []
    bought_stock = []

    ActiveRecord::Base.transaction do
      roster_ids.each do |driver_id|
        driver = Driver.find(driver_id)
        result = Fantasy::BuyDriver.new(portfolio: @portfolio.reload, driver: driver, race: @next_race).call
        if result[:error]
          errors << "#{driver.fullname}: #{result[:error]}"
          raise ActiveRecord::Rollback
        end
        bought_roster << driver.fullname
      end

      if stock_orders.any?
        stock_portfolio = current_user.fantasy_stock_portfolio_for(@portfolio.season)
        if stock_portfolio
          stock_orders.each do |order|
            driver = Driver.find(order[:driver_id])
            qty = (order[:quantity] || 1).to_i
            direction = order[:direction]
            svc = direction == "short" ? Fantasy::Stock::OpenShort : Fantasy::Stock::BuyShares
            result = svc.new(portfolio: stock_portfolio.reload, driver: driver, quantity: qty, race: @next_race).call
            if result[:error]
              errors << "#{driver.fullname}: #{result[:error]}"
              raise ActiveRecord::Rollback
            end
            bought_stock << "#{qty}x #{driver.fullname} (#{direction})"
          end
        end
      end
    end

    [errors, bought_roster, bought_stock]
  end

  def build_combined_entries
    stock_by_user = @stock_entries.index_by { |e| e[:portfolio].user_id }

    combined = @roster_entries.map do |e|
      p = e[:portfolio]
      roster_net = p.profit_loss
      sp = stock_by_user[p.user_id]
      stock_net = sp&.dig(:portfolio)&.profit_loss || 0
      total_return = p.total_return
      { user: p.user, roster_net: roster_net, stock_net: stock_net == 0 ? nil : stock_net,
        roster_value: e[:value], stock_value: sp ? sp[:value] : 0,
        total_value: e[:value] + (sp ? sp[:value] : 0), net_value: total_return }
    end

    @stock_entries.each do |e|
      sp = e[:portfolio]
      next if combined.any? { |c| c[:user].id == sp.user_id }
      stock_net = sp.profit_loss
      combined << { user: sp.user, roster_net: nil, stock_net: stock_net,
                    roster_value: nil, stock_value: e[:value],
                    total_value: e[:value], net_value: stock_net }
    end

    combined.sort_by { |c| -c[:net_value] }
  end

  def compute_combined_deltas
    roster_ids = @roster_entries.map { |e| e[:portfolio].id }
    roster_starts = @roster_entries.each_with_object({}) do |e, h|
      p = e[:portfolio]
      # Use total_starting_capital only if the stock portfolio existed when
      # the earliest snapshot was taken; otherwise the snapshot predates
      # stock capital and comparing against it would show a false loss.
      sp = p.stock_portfolio
      earliest_snap = p.snapshots.order(:created_at).first
      stock_existed = sp && earliest_snap && sp.created_at <= earliest_snap.created_at
      h[p.id] = stock_existed ? p.total_starting_capital : p.starting_capital
    end
    stock_ids = @stock_entries.map { |e| e[:portfolio].id }
    stock_starts = @stock_entries.each_with_object({}) { |e, h| h[e[:portfolio].id] = e[:portfolio].total_invested }
    @roster_deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, roster_ids, starting_values: roster_starts)
    @stock_deltas = last_race_deltas(FantasyStockSnapshot, :fantasy_stock_portfolio_id, stock_ids, starting_values: stock_starts)

    roster_by_user = @roster_entries.index_by { |e| e[:portfolio].user_id }
    stock_by_user = @stock_entries.index_by { |e| e[:portfolio].user_id }
    @combined_entries.each do |c|
      r_entry = roster_by_user[c[:user].id]
      s_entry = stock_by_user[c[:user].id]
      r_delta = r_entry ? (@roster_deltas[r_entry[:portfolio].id] || 0) : 0
      s_delta = !r_entry && s_entry ? (@stock_deltas[s_entry[:portfolio].id] || 0) : 0
      c[:last_race] = r_delta + s_delta
    end
  end

  def auto_create_stock_portfolio_if_ready
    return unless Setting.fantasy_stock_market?
    return if current_user.fantasy_stock_portfolio_for(@portfolio.season)

    roster_count = @portfolio.reload.active_roster_entries.count
    return unless roster_count >= 2

    Fantasy::Stock::CreatePortfolio.new(user: current_user, season: @portfolio.season).call
  rescue => e
    Rails.logger.error("Auto stock portfolio creation failed: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
  end

end
