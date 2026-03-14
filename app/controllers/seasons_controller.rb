class SeasonsController < ApplicationController
  include StandingsData

  def index
    all_seasons = Season.includes(:drivers, :races).sorted_by_year
    @all_years = all_seasons.map { |s| s.year.to_i }

    if params[:from_year].present?
      from = params[:from_year].to_i
      to = params[:to_year].present? ? params[:to_year].to_i : @all_years.first
      @from_year = from
      @to_year = to
      @filtered = true
      @seasons = all_seasons.select { |s| y = s.year.to_i; y >= from && y <= to }
    else
      @seasons = all_seasons
    end

    @champions_by_season = DriverStanding.where(season_end: true, position: 1)
                        .includes(:driver, race: :season)
                        .index_by { |ds| ds.race.season_id }
    @champion_colors = champion_colors_by_season(@seasons)
  end

  def show
    @season = Season.find_by!(year: params[:id])
    @points_system = @season.points_system
    set_season_champion_accent(@season)
    set_current_champion_accent if @page_accent == DEFAULT_ACCENT
    @next_season = @season.next_season
    @previous_season = @season.previous_season
    @sorted_races = @season.races.order(round: :asc).includes(:circuit)

    race_ids = @sorted_races.pluck(:id)
    all_standings = DriverStanding.where(race_id: race_ids).includes(driver: [:countries, :season_drivers])
    @driver_driver_standings = all_standings.group_by(&:driver_id).values
      .reject(&:blank?).sort_by { |ds| -ds.last.points }
    @standings_extras = build_standings_extras(@season)

    latest_standings = @season.latest_driver_standings.sort_by(&:position)
    @sd_index = SeasonDriver.where(season: @season).includes(:constructor, driver: :countries).index_by(&:driver_id)

    build_season_stats(race_ids, latest_standings)
    build_constructor_standings(latest_standings)
    build_grid_data(race_ids, latest_standings)
    build_season_recap(race_ids)
    build_pre_season_data(latest_standings)
  end

  private

  def build_season_stats(race_ids, latest_standings)
    @races_completed = Race.where(id: race_ids).joins(:race_results).distinct.count
    @total_races = @sorted_races.count
    @leader_standing = latest_standings.first
    elo_values = latest_standings.filter_map { |ds| @standings_extras[ds.driver_id]&.dig(:elo) }
    @avg_field_elo = elo_values.present? ? (elo_values.sum.to_f / elo_values.size).round : nil

    max_wins = latest_standings.map { |ds| ds.wins || 0 }.max
    @most_wins_drivers = max_wins.to_i > 0 ? latest_standings.select { |ds| (ds.wins || 0) == max_wins } : []

    @champion_standing = DriverStanding.find_by(race: @season.last_race, position: 1, season_end: true)
    if @champion_standing
      @champion = @champion_standing.driver
      @champion_constructor = @champion.constructor_for(@season)
    end

    @is_current_season = @season.year.to_i == Setting.effective_today.year
    if @is_current_season
      @latest_race = @season.latest_race
      if @latest_race
        @podium_results = @latest_race.race_results
                            .where(position_order: 1..3)
                            .order(position_order: :asc)
                            .includes(driver: :countries, constructor: [])
      end
    end
  end

  def build_constructor_standings(latest_standings)
    stats = Hash.new { |h, k| h[k] = { points: 0, wins: 0, seconds: 0, thirds: 0 } }
    latest_standings.each do |ds|
      c = @sd_index[ds.driver_id]&.constructor
      next unless c
      s = stats[c.id]
      s[:points] += ds.points || 0
      s[:wins] += ds.wins || 0
      s[:seconds] += ds.second_places || 0
      s[:thirds] += ds.third_places || 0
    end
    return if stats.empty?

    leader_id = stats.max_by { |_, s| s[:points] }.first
    leader_constructor = Constructor.find(leader_id)
    @constructor_leader = OpenStruct.new(
      constructor: leader_constructor,
      points: stats[leader_id][:points],
      wins: stats[leader_id][:wins]
    )

    constructors_by_id = Constructor.where(id: stats.keys).index_by(&:id)
    constructor_elo_diffs = build_constructor_elo_diffs
    constructor_season_elos = build_constructor_season_elos

    @constructor_standings_full = stats.map do |cid, s|
      c = constructors_by_id[cid]
      season_elo = constructor_season_elos[cid]
      s.merge(constructor: c,
              elo: season_elo || c&.display_elo&.round,
              peak_elo: c&.display_peak_elo&.round,
              elo_diff: constructor_elo_diffs[cid])
    end.sort_by { |e| -e[:points] }

    # Expose for champion recap
    @_constructor_pts = stats.transform_values { |s| s[:points] }
    @_constructor_wins_map = stats.transform_values { |s| s[:wins] }
  end

  # End-of-season constructor Elo from the last race result of the season
  def build_constructor_season_elos
    return {} unless @season.latest_race

    new_col = Setting.elo_column(:new_constructor_elo)
    elos = {}
    RaceResult.where(race: @season.latest_race).where.not(new_col => nil).each do |rr|
      next unless rr.constructor_id
      # Take the value from any result for this constructor (all should be the same post-race)
      elos[rr.constructor_id] ||= rr.send(new_col)&.round
    end
    elos
  end

  def build_constructor_elo_diffs
    return {} unless @season.latest_race

    new_col = Setting.elo_column(:new_constructor_elo)
    old_col = Setting.elo_column(:old_constructor_elo)
    diffs = {}
    RaceResult.where(race: @season.latest_race).where.not(new_col => nil, old_col => nil).each do |rr|
      next unless rr.constructor_id
      diffs[rr.constructor_id] ||= ((rr.send(new_col) || 0) - (rr.send(old_col) || 0)).round
    end
    diffs
  end

  def build_grid_data(race_ids, latest_standings)
    @season_drivers = latest_standings.filter_map { |ds| @sd_index[ds.driver_id] }
    @grid_standings = latest_standings.index_by(&:driver_id)

    @season_race_results = RaceResult.where(race_id: race_ids).includes(:status)
      .each_with_object({}) { |rr, h| h[[rr.driver_id, rr.race_id]] = rr }

    @team_grid = @sd_index.values.map(&:constructor).uniq.sort_by(&:name).filter_map do |constructor|
      drivers = @sd_index.select { |_, sd| sd.constructor_id == constructor.id }.map { |_, sd| sd.driver }.uniq
      next if drivers.empty?
      { constructor: constructor, drivers: drivers }
    end
  end

  def build_season_recap(race_ids)
    new_elo_col = Setting.elo_column(:new_elo)
    old_elo_col = Setting.elo_column(:old_elo)

    season_results = RaceResult.joins(:race)
                  .where(races: { season_id: @season.id })
                  .where.not(new_elo_col => nil, old_elo_col => nil)
                  .includes(:driver, :constructor, race: :circuit)

    @season_elo_changes = season_results.group_by(&:driver_id).filter_map do |_did, results|
      sorted = results.sort_by { |rr| rr.race.date }
      season_start = sorted.first.send(old_elo_col)
      season_end = sorted.last.send(new_elo_col)
      next unless season_start && season_end
      { driver: sorted.first.driver, change: (season_end - season_start).round,
        start_elo: season_start.round, end_elo: season_end.round }
    end.sort_by { |e| -e[:change] }

    @season_biggest_gainers = @season_elo_changes.first(5)
    @season_biggest_losers = @season_elo_changes.last(5).reverse
    @season_mvp = @season_elo_changes.first
    @biggest_race_gain = season_results.max_by { |rr| (rr.send(new_elo_col) || 0) - (rr.send(old_elo_col) || 0) }
    @biggest_race_drop = season_results.min_by { |rr| (rr.send(new_elo_col) || 0) - (rr.send(old_elo_col) || 0) }

    if @champion
      latest_standings = @season.latest_driver_standings.sort_by(&:position)
      @season_top3 = latest_standings.first(3)
      @season_top3_constructors = @season_top3.each_with_object({}) { |ds, h| h[ds.driver_id] = @sd_index[ds.driver_id]&.constructor }
      constructor_points = @_constructor_pts || {}
      constructor_wins = @_constructor_wins_map || {}
      top_ids = constructor_points.sort_by { |_, pts| -pts }.first(3).map(&:first)
      constructors = Constructor.where(id: top_ids).index_by(&:id)
      @constructor_top3 = top_ids.map { |cid| { constructor: constructors[cid], points: constructor_points[cid], wins: constructor_wins[cid] || 0 } }
    end
  end

  def build_pre_season_data(latest_standings)
    @has_standings = @leader_standing.present?
    @season_race_results ||= {}
    return if @has_standings

    lineup_season = @season.lineup_season
    return unless lineup_season

    elo_col = Setting.elo_column(:elo)
    @season_drivers = SeasonDriver.where(season: lineup_season, standin: [false, nil])
                        .includes(driver: :countries, constructor: [])
                        .sort_by { |sd| -sd.id }.uniq(&:driver_id)
                        .sort_by { |sd| -(sd.driver.send(elo_col) || 0) }
    @grid_standings = {}
    @grid_prev_standings = {}

    constructor_elos = Hash.new { |h, k| h[k] = [] }
    @season_drivers.each { |sd| elo = sd.driver.send(elo_col); constructor_elos[sd.constructor] << (elo || 0) if elo }
    @constructor_rankings = constructor_elos
      .map { |c, elos| { constructor: c, points: 0, wins: 0, seconds: 0, thirds: 0, elo: c.display_elo&.round, peak_elo: c.display_peak_elo&.round, elo_diff: nil, total_elo: elos.sum, avg_elo: (elos.sum.to_f / elos.size).round, drivers: elos.size } }
      .sort_by { |e| -e[:total_elo] }

    @team_grid = Constructor.where(active: true).order(:name).map do |constructor|
      drivers = SeasonDriver.where(season: lineup_season, constructor: constructor, standin: [false, nil])
                  .includes(driver: :countries).map(&:driver).uniq
      next if drivers.empty?
      { constructor: constructor, drivers: drivers }
    end.compact
  end
end
