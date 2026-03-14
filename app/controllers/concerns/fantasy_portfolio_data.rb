module FantasyPortfolioData
  extend ActiveSupport::Concern

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
    CheckAchievementsJob.perform_later(portfolio_type: "roster", portfolio_id: portfolio.id)
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

  # Returns { portfolio_id => delta } for the most recent race snapshot
  def last_race_deltas(snapshot_class, fk, portfolio_ids, starting_values: {})
    return {} if portfolio_ids.empty?

    # Get the two most recent snapshots per portfolio
    snapshots = snapshot_class.where(fk => portfolio_ids)
                              .joins(:race)
                              .order("races.date DESC")
                              .to_a
                              .group_by(&fk)

    snapshots.each_with_object({}) do |(pid, snaps), hash|
      if snaps.size >= 2
        hash[pid] = snaps[0].value - snaps[1].value
      elsif snaps.size == 1 && starting_values[pid]
        # First race — compare against starting capital as baseline
        hash[pid] = snaps[0].value - starting_values[pid]
      else
        hash[pid] = 0
      end
    end
  end

  def stock_leaderboard_entries
    return [] unless Setting.fantasy_stock_market?
    FantasyStockPortfolio.where(season: @season)
      .includes(:user, :snapshots, holdings: :driver)
      .to_a
      .map { |p| { portfolio: p, value: p.portfolio_value, net: p.profit_loss } }
      .sort_by { |e| -e[:net] }
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
