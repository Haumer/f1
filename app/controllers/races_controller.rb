class RacesController < ApplicationController

  def show
    @race = Race.includes(
      race_results: { driver: [:countries, { season_drivers: :constructor }], constructor: [], status: [] },
      driver_standings: []
    ).find(params[:id])
    @previous_race = @race.previous_race
    @next_race = @race.next_race
    set_race_winner_accent(@race)

    results = @race.race_results.to_a
    @grid_size = results.size
    @biggest_gainer = results.max_by(&:display_elo_diff)
    @biggest_loser = results.min_by(&:display_elo_diff)
    new_elo_col = Setting.elo_column(:new_elo).to_sym
    @highest_elo_rr = results.max_by { |rr| rr.send(new_elo_col) || 0 }
    @dnf_count = results.count { |rr| rr.status&.status_type != "Finished" && !rr.status&.status_type.to_s.downcase.include?("lap") }

    # Pre-index driver standings to avoid N+1 in view
    @standings_by_driver = @race.driver_standings.index_by(&:driver_id)

    # Circuit kings
    @circuit_kings = DriverBadge.circuit_kings_for(@race.circuit_id)

    # Pre-index constructors per driver for this season to avoid N+1
    season = @race.season
    driver_ids = results.map(&:driver_id)
    season_drivers = SeasonDriver.where(season: season, driver_id: driver_ids).includes(:constructor)
    @constructor_by_driver = season_drivers.each_with_object({}) do |sd, h|
      h[sd.driver_id] = sd.constructor
    end

    # Qualifying results
    @qualifying_results = @race.qualifying_results.sorted.includes(:driver, :constructor)

    # Pre-race: expected drivers + session schedule
    unless @race.has_results?
      @session_schedule = @race.session_schedule
      quali_grid = @qualifying_results.index_by(&:driver_id)

      @expected_drivers = season.season_drivers
                            .includes(driver: :countries, constructor: [])
                            .map do |sd|
                              qr = quali_grid[sd.driver_id]
                              { driver: sd.driver, constructor: sd.constructor, grid: qr&.position }
                            end

      if quali_grid.any?
        # Drivers with grid positions first (by position), then the rest by Elo
        @expected_drivers.sort_by! { |d| [d[:grid] ? 0 : 1, d[:grid] || 999, -(d[:driver].elo_v2 || 0)] }
      else
        @expected_drivers.sort_by! { |d| -(d[:driver].elo_v2 || 0) }
      end
    end
  end

  def calendar
    @season = current_season
    @races = @season.races.order(round: :asc).includes(:circuit, race_results: { driver: :countries, constructor: [] })
    @today = Setting.effective_today
    @now = Time.current

    # Build sessions indexed by date for calendar cells
    @sessions_by_date = {}
    all_sessions = []
    @races.each do |race|
      race.session_schedule.each do |session|
        entry = session.merge(race: race)
        @sessions_by_date[session[:date]] ||= []
        @sessions_by_date[session[:date]] << entry
        all_sessions << entry
      end
    end

    # Find the next upcoming session (for countdown + focus)
    @next_session = all_sessions
      .select { |s| s[:starts_at].present? && s[:starts_at] > @now }
      .min_by { |s| s[:starts_at] }

    # The race that contains the next session (for focus week)
    @focus_race = @next_session&.dig(:race)
  end

  def index
    @all_seasons = Season.sorted_by_year.to_a
    @seasons_by_year = @all_seasons.index_by { |s| s.year.to_i }

    if params[:from_year].present?
      # Filter mode: show all races from the given year onwards
      from = params[:from_year].to_i
      to = params[:to_year].present? ? params[:to_year].to_i : Date.current.year
      @from_year = from
      @to_year = to
      @filtered = true
      base_scope = Race.joins(:race_results).where(year: from..to).distinct
      @races = base_scope.sorted_by_most_recent
                .includes(race_results: { driver: :countries, constructor: [] }, circuit: [])
    else
      # Default: current season + last 3 seasons, with load more
      @seasons_shown = (params[:seasons] || 4).to_i
      current_year = current_season.year.to_i
      years = (current_year - @seasons_shown + 1..current_year).to_a
      base_scope = Race.joins(:race_results).where(year: years).distinct
      @races = base_scope.sorted_by_most_recent
                .includes(race_results: { driver: :countries, constructor: [] }, circuit: [])
      @has_more = @all_seasons.any? { |s| s.year.to_i < years.min }
    end

    # Upcoming races (no results yet) for current season
    unless @filtered
      today = Setting.effective_today
      current_season_record = current_season
      all_upcoming = current_season_record.races
                       .left_joins(:race_results)
                       .where(race_results: { id: nil })
                       .where("races.date >= ?", today)
                       .order(date: :asc)
                       .includes(:circuit)
      @upcoming_preview = all_upcoming.first(3)
      @upcoming_total = all_upcoming.size
      @show_all_upcoming = params[:show_upcoming] == "1"
      @all_upcoming = @show_all_upcoming ? all_upcoming : []
      @current_season = current_season_record
    end
  end

  def highest_elo
    new_elo_col = Setting.elo_column(:new_elo)
    @race_results = RaceResult.joins(:race)
      .where.not(new_elo_col => nil)
      .order(new_elo_col => :desc)
      .limit(100)
      .includes(:driver, :constructor, race: :circuit)
  end

  def podiums
    @drivers = Driver.where("podiums > 0").includes(:countries).order(podiums: :desc).limit(50)
  end

  CHAMPION_ERAS = {
    "Pioneers"      => 1950..1969,
    "Ground Effect"  => 1970..1989,
    "Modern"        => 1990..2009,
    "Hybrid"        => 2010..2099
  }.freeze

  def winners
    standings = Driver.champion_standings.to_a
    champion_drivers = standings.map(&:driver).uniq
    champion_ids = champion_drivers.map(&:id)

    # Batch-load all race results for champions to avoid N+1
    all_results = RaceResult.where(driver_id: champion_ids)
                .includes(race: [:circuit, :season])
                .group_by(&:driver_id)

    # Group champions by era — a driver appears in every era where they won a title
    champion_title_years = standings.group_by(&:driver).transform_values do |titles|
      titles.map { |t| t.race.season.year.to_i }
    end

    @eras = CHAMPION_ERAS.map do |era_name, year_range|
      era_drivers = champion_title_years.select { |_, years| years.any? { |y| year_range.cover?(y) } }.keys
      era_results = era_drivers.map { |d| all_results[d.id] || [] }
      { name: era_name, years: "#{year_range.first}–#{year_range.last > 2050 ? 'present' : year_range.last}", range: year_range, results: era_results, drivers: era_drivers }
    end

    @active_era = params[:era].present? ? params[:era].to_i : 3

    # Championship count data for table and chart
    @champion_data = standings.group_by(&:driver).map do |driver, titles|
      years = titles.map { |t| t.race.season.year }.sort
      [driver, { count: titles.size, years: years }]
    end.sort_by { |_, d| -d[:count] }
  end
end
