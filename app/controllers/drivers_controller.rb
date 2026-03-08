class DriversController < ApplicationController
  include StandingsData
  def show
    @driver = Driver.includes(
      season_drivers: :constructor,
      driver_standings: { race: :season },
      race_results: { race: :circuit, constructor: [], status: [] }
    ).find(params[:id])
    set_driver_accent(@driver)
    @season_1st_place_finishes = @driver.driver_standings.select { |ds| ds.position == 1 && ds.season_end }.sort_by { |ds| ds.race.date }
    @season_2nd_place_finishes = @driver.driver_standings.select { |ds| ds.position == 2 && ds.season_end }.sort_by { |ds| ds.race.date }
    @season_3rd_place_finishes = @driver.driver_standings.select { |ds| ds.position == 3 && ds.season_end }.sort_by { |ds| ds.race.date }
    @race_result_counts = @driver.race_results.group(:position_order).count

    # Elo ranking context (version-aware, using safe column names)
    peak = @driver.display_peak_elo
    current = @driver.display_elo
    peak_col = Setting.elo_column(:peak_elo)
    elo_col = Setting.elo_column(:elo)
    @peak_elo_rank = peak ? Driver.where("#{peak_col} >= ?", peak).count : nil
    @active_elo_rank = (@driver.active && current) ? Driver.active.where("#{elo_col} >= ?", current).count : nil
    @elo_tier = helpers.elo_tier(peak)

    @badges = @driver.badges.ordered_by_tier.order(:id)
  end

  def grid
    season = current_season
    lineup_season = SeasonDriver.where(season: season).exists? ? season : season.previous_season
    @season_year = season.year
    elo_col = Setting.elo_column(:elo)

    @season_drivers = SeasonDriver.where(season: lineup_season, standin: [false, nil])
                        .includes(driver: :countries, constructor: [])
                        .sort_by { |sd| -sd.id }
                        .uniq(&:driver_id)
                        .sort_by { |sd| -(sd.driver.send(elo_col) || 0) }

    @grid_standings = season.latest_driver_standings.index_by(&:driver_id)
    @standings_extras = build_standings_extras(season)
  end

  def index
    peak_col = Setting.elo_column(:peak_elo)
    base = Driver.select("drivers.*, (SELECT COUNT(*) FROM race_results WHERE race_results.driver_id = drivers.id) AS race_count")
           .includes(:countries, season_drivers: [:constructor, :season])
    if params[:search].present? && params[:search][:query].to_s.length > 1
      @drivers = Driver.name_and_constructor_search(params[:search][:query])
               .select("drivers.*, (SELECT COUNT(*) FROM race_results WHERE race_results.driver_id = drivers.id) AS race_count")
               .includes(:countries, season_drivers: [:constructor, :season])
    else
      @drivers = base.where.not(peak_col => nil).order(wins: :desc, podiums: :desc, peak_col => :desc).limit(100)
    end

    @page = (params[:page] || 1).to_i
    @per_page = 100
    @offset = (@page - 1) * @per_page
  end

  def peak_elo
    peak_col = Setting.elo_column(:peak_elo)
    new_elo_col = Setting.elo_column(:new_elo).to_sym
    threshold = 2450
    @drivers = Driver.where("#{peak_col} > ?", threshold).order(peak_col => :desc)
    @race_results = Driver.elite.includes(race_results: { race: :circuit, constructor: [] }).map { |driver| driver.race_results.max_by(&new_elo_col) }.compact.sort_by { |rr| -rr.send(new_elo_col) }
    @peak_race_by_driver = @race_results.index_by(&:driver_id)
  end

  def current_active_elo
    elo_col = Setting.elo_column(:elo)
    @drivers = Driver.active.includes(:countries, season_drivers: :constructor).order(elo_col => :desc)
  end

  def compare
    if params[:driver_ids].present?
      ids = params[:driver_ids].to_s[0, 100].split(",").map(&:to_i).first(7)
    else
      elo_col = Setting.elo_column(:elo)
      ids = Driver.active.where.not(elo_col => nil).order(elo_col => :desc).limit(3).pluck(:id)
    end
    @drivers = Driver.where(id: ids).includes(:countries, :driver_standings)
  end

  def by_nationality
    peak_col = Setting.elo_column(:peak_elo)

    all_drivers = Driver.where.not(peak_col => nil)
              .where.not(nationality: [nil, ""])
              .includes(season_drivers: :constructor)

    @nationalities = all_drivers.group_by(&:nationality)
                  .map do |nationality, drivers|
      sorted = drivers.sort_by { |d| -(d.send(peak_col) || 0) }
      {
        nationality: nationality,
        count: sorted.size,
        top_peak_elo: sorted.first&.send(peak_col)&.round,
        top_driver: sorted.first,
      }
    end.sort_by { |n| -n[:count] }

    if params[:nationality].present?
      @selected_nationality = params[:nationality]
      @country_drivers = Driver.where(nationality: @selected_nationality)
                   .where.not(peak_col => nil)
                   .order(peak_col => :desc)
                   .includes(season_drivers: :constructor)
    end
  end

  def search
    if params[:q].present? && params[:q].length >= 2
      drivers = Driver.name_and_constructor_search(params[:q]).limit(10)
      render json: drivers.map { |d| { id: d.id, name: d.fullname, peak_elo: d.display_peak_elo&.round } }
    else
      render json: []
    end
  end
end
