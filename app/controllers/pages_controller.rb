class PagesController < ApplicationController
  include StandingsData
  include HomepageData

  def home
    set_current_champion_accent
    @season = resolve_season
    return unless @season

    @today = Setting.effective_today
    @standings_season = resolve_standings_season
    @standings_extras = @standings_season ? build_standings_extras(@standings_season) : {}

    build_recap_constructors
    build_latest_race_and_movers
    build_quick_stats
    build_season_driver_grid
    build_next_race_and_champion
    build_constructor_top3
    prepare_homepage_phase
    load_fantasy_portfolio
  end

  def about
    set_current_champion_accent
  end

  def fantasy_guide
    set_current_champion_accent
  end

  def terms
    set_current_champion_accent
  end

  def elo
    peak_col = Setting.elo_column(:peak_elo)
    thresholds = [2600, 2450, 2300, 2100]
    @tier_counts = {
      elite: Driver.where("#{peak_col} >= ?", thresholds[0]).count,
      world_class: Driver.where("#{peak_col} >= ? AND #{peak_col} < ?", thresholds[1], thresholds[0]).count,
      strong: Driver.where("#{peak_col} >= ? AND #{peak_col} < ?", thresholds[2], thresholds[1]).count,
      average: Driver.where("#{peak_col} >= ? AND #{peak_col} < ?", thresholds[3], thresholds[2]).count,
      developing: Driver.where("#{peak_col} < ?", thresholds[3]).where.not(peak_col => nil).count
    }
    @total_drivers = Driver.where.not(peak_col => nil).count
    @total_races = Race.joins(:race_results).distinct.count

    @recent_races = Race.joins(:race_results).distinct
                        .includes(:circuit, :season).order(date: :desc).limit(10)
    @example_race = params[:race_id].present? ? Race.find_by(id: params[:race_id]) : @recent_races.first

    if @example_race
      @example_results = @example_race.race_results.includes(driver: :countries, constructor: []).order(:position_order)
      old_elo_col = Setting.elo_column(:old_elo)
      elo_values = @example_results.filter_map { |rr| rr.send(old_elo_col) }
      @avg_field_elo = elo_values.any? ? (elo_values.sum / elo_values.size).round : nil
      @example_biggest_gainer = @example_results.max_by(&:display_elo_diff)
      @example_biggest_loser = @example_results.min_by(&:display_elo_diff)
    end
  end

  private

  def resolve_season
    effective_year = Setting.effective_today.year
    current = Season.find_by(year: effective_year.to_s)
    first_race_date = current&.races&.order(:date)&.first&.date
    today = Setting.effective_today
    active = current&.latest_driver_standings&.any? || (first_race_date && first_race_date - 1.month <= today)
    active ? current : Season.sorted_by_year.joins(races: :driver_standings).distinct.first
  end

  def resolve_standings_season
    if @season.latest_driver_standings&.any?
      @season
    else
      Season.sorted_by_year.where.not(id: @season.id).joins(races: :driver_standings).distinct.first
    end
  end

  def build_recap_constructors
    return unless @standings_season && @standings_season != @season

    top3 = @standings_season.latest_driver_standings&.first(3)
    return unless top3&.any?

    sd_index = SeasonDriver.where(season: @standings_season).includes(:constructor).index_by(&:driver_id)
    @recap_constructors = top3.each_with_object({}) { |ds, h| h[ds.driver_id] = sd_index[ds.driver_id]&.constructor }
  end

  def build_latest_race_and_movers
    @latest_race = @standings_season&.latest_race
    @podium_results = @latest_race&.race_results&.where(position_order: 1..3)
                                  &.order(position_order: :asc)
                                  &.includes(driver: :countries, constructor: [])

    return unless @standings_extras.present?

    sorted_extras = @standings_extras.select { |_id, e| e[:elo_diff].present? }
    @elo_gainers = sorted_extras.sort_by { |_id, e| -(e[:elo_diff] || 0) }.first(5)
    @elo_losers  = sorted_extras.sort_by { |_id, e| e[:elo_diff] || 0 }.first(5)
    mover_ids = (@elo_gainers + @elo_losers).map(&:first)
    @drivers_by_id = Driver.where(id: mover_ids).includes(:countries, season_drivers: :constructor).index_by(&:id)
  end

  def build_quick_stats
    @races_completed = if Setting.simulated_date
                         @season.races.joins(:race_results).where("races.date <= ?", @today).distinct.count
                       else
                         @season.races.joins(:race_results).distinct.count
                       end
    @total_races = @season.races.count
    @leader = @standings_season&.latest_driver_standings&.first
    @highest_elo_driver = Driver.active.order(Setting.elo_column(:elo) => :desc).first
    @most_wins = @standings_season&.latest_driver_standings&.max_by { |ds| ds.wins || 0 }

    latest_standings = @season.latest_driver_standings
    @grid_standings = latest_standings.index_by(&:driver_id)
  end

  def build_season_driver_grid
    lineup_season = SeasonDriver.where(season: @season).exists? ? @season : @season.previous_season
    return unless lineup_season

    sd_all = SeasonDriver.where(season: lineup_season, standin: [false, nil])
               .includes(driver: :countries, constructor: [])
               .sort_by { |sd| -sd.id }.uniq(&:driver_id)

    @season_drivers = if @grid_standings.any?
                        sd_all.sort_by { |sd| @grid_standings[sd.driver_id]&.position || 999 }
                      else
                        sd_all.sort_by { |sd| -(sd.driver.send(Setting.elo_column(:elo)) || 0) }
                      end
  end

  def build_next_race_and_champion
    @next_race = @season.next_race
    @next_race ||= Race.where("date >= ?", @today).order(:date).includes(:circuit).first

    if @standings_season
      @season_complete = if Setting.simulated_date
                           @today > (@standings_season.last_race&.date || Date.new(2099))
                         else
                           @standings_season.last_race&.race_results&.any?
                         end
    end

    return unless @season_complete && @standings_season

    champion_standing = DriverStanding.find_by(race: @standings_season.last_race, position: 1, season_end: true)
    if champion_standing
      @champion = champion_standing.driver
      @champion_standing = champion_standing
      @champion_constructor = @champion.constructor_for(@standings_season)
    end
  end

  def build_constructor_top3
    return unless @standings_season && @standings_season != @season

    last_race = @standings_season.races.order(:round).last
    return unless last_race

    race_ids = @standings_season.races.pluck(:id)
    rr_points = RaceResult.where(race_id: race_ids).where.not(constructor_id: nil)
                  .group(:driver_id, :constructor_id).sum(:points)
    ds_totals = DriverStanding.where(race: last_race).pluck(:driver_id, :points, :wins)
                  .to_h { |did, pts, w| [did, { points: pts || 0, wins: w || 0 }] }

    constructor_points = Hash.new(0.0)
    rr_points.each do |(driver_id, constructor_id), rr_pts|
      ds = ds_totals[driver_id]
      next unless ds
      driver_rr_total = rr_points.select { |(did, _), _| did == driver_id }.values.sum
      if driver_rr_total > 0
        constructor_points[constructor_id] += ds[:points] * (rr_pts.to_f / driver_rr_total)
      end
    end
    constructor_wins = RaceResult.where(race_id: race_ids, position_order: 1)
                         .where.not(constructor_id: nil).group(:constructor_id).count

    top_ids = constructor_points.sort_by { |_, pts| -pts }.first(3).map(&:first)
    constructors = Constructor.where(id: top_ids).index_by(&:id)
    @constructor_top3 = top_ids.map { |cid| { constructor: constructors[cid], points: constructor_points[cid].round, wins: constructor_wins[cid] || 0 } }
  end

  def prepare_homepage_phase
    @contextual_race = find_contextual_race
    @homepage_phase = determine_homepage_phase
    prepare_phase_data
  end

  def load_fantasy_portfolio
    return unless current_user

    @fantasy_portfolio = current_user.fantasy_portfolio_for(@season)
    @fantasy_stock_portfolio = current_user.fantasy_stock_portfolio_for(@season)
    if @fantasy_portfolio
      @fantasy_support = ConstructorSupport.current_for(current_user, @season)
      @fantasy_rank = @fantasy_portfolio.snapshots.order(created_at: :desc).first&.rank
    end
  end
end
