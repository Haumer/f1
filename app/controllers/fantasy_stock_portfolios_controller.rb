class FantasyStockPortfoliosController < ApplicationController
  include FantasyPortfolioData

  before_action :authenticate_user!
  before_action :set_portfolio, only: [:market, :buy, :sell, :short_open, :short_close, :buy_batch]
  before_action :set_next_race, only: [:market, :buy, :sell, :short_open, :short_close, :buy_batch]
  after_action :verify_authorized, only: [:buy, :sell, :short_open, :short_close, :buy_batch, :market]

  def market
    season_driver_ids = SeasonDriver.where(season_id: @portfolio.season_id).select(:driver_id)
    @drivers = Driver.where(id: season_driver_ids)
                     .order(Arel.sql("COALESCE(drivers.elo_v2, 0) DESC"))
                     .includes(:countries)
    @can_trade = @next_race && @portfolio.can_trade?(@next_race)
    @holdings_by_driver = @portfolio.active_holdings.group_by(&:driver_id)
    @prices_by_driver = Fantasy::Pricing.prices_for_season(@drivers.map(&:id), @portfolio.season)
    @selected_driver_id = @drivers.find { |driver| driver.id.to_s == params[:driver].to_s }&.id
    if request.format.json?
      response.headers["Cache-Control"] = "no-store"
      render json: {
        can_trade: !!@can_trade, race_id: @next_race&.id,
        closes_at: @portfolio.trading_closes_at(@next_race)&.iso8601,
        cash: @portfolio.available_cash, used_positions: @portfolio.position_count,
        drivers: @drivers.map { |driver| {
          id: driver.id, name: driver.fullname, price: @prices_by_driver[driver.id],
          owned: @holdings_by_driver.fetch(driver.id, []).map(&:direction)
        } }
      }
      return
    end
    @constructors_by_driver = constructors_for_drivers(@drivers)
    @elo_trends = elo_trends_for(@drivers.map(&:id))
    @demand_by_driver = SeasonDriver.where(season_id: @portfolio.season_id)
                                     .pluck(:driver_id, :net_demand).to_h
  end

  def buy
    driver = Driver.find(params[:driver_id])
    quantity = (params[:quantity] || 1).to_i
    result = Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: driver, quantity: quantity, race: @next_race).call

    if result[:error]
      redirect_to market_fantasy_stock_portfolio_path(@portfolio), alert: result[:error]
    else
      check_stock_achievements(@portfolio)
      redirect_to fantasy_overview_path(current_user.username), notice: "Bought #{quantity}x #{driver.fullname}!"
    end
  end

  def sell
    driver = Driver.find(params[:driver_id])
    quantity = (params[:quantity] || 1).to_i
    result = Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: driver, quantity: quantity, race: @next_race).call

    if result[:error]
      redirect_to fantasy_overview_path(current_user.username), alert: result[:error]
    else
      check_stock_achievements(@portfolio)
      redirect_to fantasy_overview_path(current_user.username), notice: "Sold #{quantity}x #{driver.fullname}!"
    end
  end

  def short_open
    driver = Driver.find(params[:driver_id])
    quantity = (params[:quantity] || 1).to_i
    result = Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: driver, quantity: quantity, race: @next_race).call

    if result[:error]
      redirect_to market_fantasy_stock_portfolio_path(@portfolio), alert: result[:error]
    else
      check_stock_achievements(@portfolio)
      redirect_to fantasy_overview_path(current_user.username), notice: "Shorted #{quantity}x #{driver.fullname}!"
    end
  end

  def short_close
    driver = Driver.find(params[:driver_id])
    quantity = (params[:quantity] || 1).to_i
    result = Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: driver, quantity: quantity, race: @next_race).call

    if result[:error]
      redirect_to fantasy_overview_path(current_user.username), alert: result[:error]
    else
      check_stock_achievements(@portfolio)
      redirect_to fantasy_overview_path(current_user.username), notice: "Closed short on #{driver.fullname}!"
    end
  end

  def buy_batch
    orders = params[:orders].is_a?(Array) ? params[:orders].reject(&:blank?) : []
    errors = []
    bought = []

    @portfolio.with_lock do
      if orders.empty? || orders.size > FantasyStockPortfolio::MAX_POSITIONS || orders.any? { |o| !o.is_a?(ActionController::Parameters) } || orders.map { |o| o[:driver_id].to_s }.uniq.size != orders.size
        errors << "Choose at least one trade, with one order per driver."
        raise ActiveRecord::Rollback
      end
      orders.each do |order|
        driver = Driver.joins(:season_drivers).find_by(id: order[:driver_id], season_drivers: { season_id: @portfolio.season_id })
        qty = (order[:quantity] || 1).to_i
        direction = order[:direction]

        if !driver || !%w[long short].include?(direction) || @portfolio.active_holdings.where(driver: driver).where.not(direction: direction).exists?
          errors << "That trade is no longer available. Review your cart."
          raise ActiveRecord::Rollback
        end
        # A saved/browser-cached draft is not a price promise. Services still
        # calculate execution prices; reject changed quotes before any trade.
        if order[:quoted_price].present? && (order[:quoted_price].to_d - @portfolio.share_price(driver).to_d).abs > 0.000001
          errors << "#{driver.fullname}'s price changed. Review the refreshed cart."
          raise ActiveRecord::Rollback
        end

        result = if direction == "short"
          Fantasy::Stock::OpenShort.new(portfolio: @portfolio.reload, driver: driver, quantity: qty, race: @next_race).call
        else
          Fantasy::Stock::BuyShares.new(portfolio: @portfolio.reload, driver: driver, quantity: qty, race: @next_race).call
        end

        if result[:error]
          errors << "#{driver.fullname}: #{result[:error]}"
          raise ActiveRecord::Rollback
        else
          bought << (direction == "long" ? "Bought #{qty}x #{driver.fullname}" : "Opened short: #{qty}x #{driver.fullname}")
        end
      end
    end

    if errors.any?
      redirect_to market_fantasy_stock_portfolio_path(@portfolio), alert: errors.join(". ")
    else
      check_stock_achievements(@portfolio)
      flash[:stock_cart_cleared] = @portfolio.id
      redirect_to fantasy_overview_path(current_user.username), notice: bought.join(". ")
    end
  end

  private

  def set_portfolio
    @portfolio = FantasyStockPortfolio.find(params[:id])
    authorize @portfolio
  end

  def set_next_race
    @next_race = @portfolio.season.next_race ||
                 Race.where("date >= ?", Date.current).order(:date).first
  end

  def check_stock_achievements(portfolio)
    CheckAchievementsJob.perform_later(portfolio_type: "stock", portfolio_id: portfolio.id)
  end
end
