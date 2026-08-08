class ConstructorsController < ApplicationController
  def index
    @season = current_season
    lineup_season = @season.lineup_season

    # Build team grid with drivers
    season_drivers = SeasonDriver.where(season: lineup_season, standin: [false, nil])
                       .includes(:constructor, driver: :countries)
    sd_by_constructor = season_drivers.group_by(&:constructor_id)

    # Constructor standings from latest race
    latest_standings = @season.latest_driver_standings
    sd_index = season_drivers.index_by(&:driver_id)
    constructor_stats = compute_constructor_stats(latest_standings, sd_index)

    active_constructors = Constructor.where(active: true).index_by(&:id)
    @team_standings = active_constructors.values.filter_map do |constructor|
      drivers = (sd_by_constructor[constructor.id] || []).map(&:driver).uniq
      stats = constructor_stats[constructor.id] || { points: 0, wins: 0, podiums: 0 }
      {
        constructor: constructor,
        drivers: drivers,
        points: stats[:points],
        wins: stats[:wins],
        podiums: stats[:podiums],
        elo: constructor.display_elo&.round,
        peak_elo: constructor.display_peak_elo&.round
      }
    end.sort_by { |e| [-e[:points], -(e[:elo] || 0)] }

    # Championship history (all-time)
    season_end_race_ids = Race.where(season_end: true).pluck(:id)
    champ_standings = ConstructorStanding.where(race_id: season_end_race_ids, position: 1)
                        .includes(:constructor, race: :season)
    champ_by_constructor = champ_standings.group_by(&:constructor_id)
    @championship_leaders = champ_by_constructor.map do |cid, standings|
      c = standings.first.constructor
      years = standings.map { |cs| cs.race.season.year }.sort
      { constructor: c, count: standings.size, years: years }
    end.sort_by { |e| [-e[:count], e[:constructor].name] }

    # Elo rankings (top 10 active)
    elo_col = Setting.elo_column(:elo)
    @elo_rankings = Constructor.where(active: true)
                      .where.not(elo_col => nil)
                      .order(elo_col => :desc)
                      .limit(10).to_a

    @historical_constructors = Constructor.where(active: [false, nil])
      .joins(:race_results)
      .select("constructors.*, COUNT(DISTINCT race_results.race_id) as race_count")
      .group("constructors.id")
      .having("COUNT(DISTINCT race_results.race_id) >= 10")
      .order("race_count DESC")
  end

  def grid
    @season = current_season
    lineup_season = @season.lineup_season
    @season_year = @season.year

    season_drivers = SeasonDriver.where(season: lineup_season, standin: [false, nil])
                       .includes(:constructor, driver: :countries)
    sd_by_constructor = season_drivers.group_by(&:constructor_id)
    sd_index = season_drivers.index_by(&:driver_id)

    # Constructor standings
    latest_standings = @season.latest_driver_standings
    constructor_stats = compute_constructor_stats(latest_standings, sd_index)

    # Recent form per driver (last 5 results)
    all_driver_ids = season_drivers.map(&:driver_id)
    recent_results = RaceResult.where(driver_id: all_driver_ids)
                       .joins(:race).order("races.date DESC")
                       .includes(race: :circuit)
                       .limit(all_driver_ids.size * 5)
    @recent_form = recent_results.group_by(&:driver_id).transform_values { |rrs| rrs.first(5) }

    @team_grid = Constructor.where(active: true).filter_map do |constructor|
      drivers = (sd_by_constructor[constructor.id] || []).map(&:driver).uniq
      next if drivers.empty?
      stats = constructor_stats[constructor.id] || { points: 0, wins: 0, podiums: 0 }
      {
        constructor: constructor,
        drivers: drivers,
        points: stats[:points],
        wins: stats[:wins],
        podiums: stats[:podiums],
        elo: constructor.display_elo&.round
      }
    end.sort_by { |e| [-e[:points], -(e[:elo] || 0)] }
  end

  def show
    @constructor = Constructor.includes(
      race_results: { race: :circuit, driver: [:countries] },
      season_drivers: { driver: [:countries], season: [] }
    ).find_by!(constructor_ref: params[:id])
    set_constructor_accent(@constructor)

    Constructors::ShowPresenter.new(
      constructor: @constructor,
      current_user: current_user,
      current_season: current_season
    ).call.each { |k, v| instance_variable_set("@#{k}", v) }
  end

  def elo_rankings
    elo_col = Setting.elo_column(:elo)
    @constructors = Constructor.where(active: true)
                   .where.not(elo_col => nil)
                   .order(elo_col => :desc)
                   .to_a
    @top_constructors = @constructors.first(10)
  end

  def best_pairings
    @pairings = Constructors::PairingCalculator.new.call
  end

  def support
    authenticate_user!
    constructor = Constructor.find_by!(constructor_ref: params[:id])
    season = current_season

    unless ConstructorSupport.can_change?(current_user, season)
      redirect_back fallback_location: constructor_path(constructor), alert: "You can't change your team right now. Swaps open at mid-season."
      return
    end

    ActiveRecord::Base.transaction do
      current_user.lock!

      ConstructorSupport.current_for(current_user, season)&.update!(active: false, ended_at: Time.current)

      support = ConstructorSupport.create!(
        user: current_user,
        constructor: constructor,
        season: season
      )

      if current_user.constructor_supports.where(season: season, bonus_granted: true).none?
        portfolio = current_user.fantasy_portfolio_for(season)
        if portfolio
          portfolio.update!(cash: portfolio.cash + ConstructorSupport::BONUS_CASH)
          portfolio.transactions.create!(
            kind: "bonus",
            amount: ConstructorSupport::BONUS_CASH,
            note: "Team allegiance bonus for supporting #{constructor.name}"
          )
          support.update!(bonus_granted: true)
        end
      end
    end

    redirect_back fallback_location: constructor_path(constructor), notice: "You are now supporting #{constructor.name}!"
  end

  def families
    @lineages = Constructor.lineages
    @families = Constructor.all_families_with_constructors
    # Pre-load all constructors referenced in lineages to avoid N+1
    all_refs = @lineages.values.flat_map { |info| info[:chain] }
    @constructors_by_ref = Constructor.where(constructor_ref: all_refs).index_by(&:constructor_ref)
  end

  private

  def compute_constructor_stats(standings, sd_index)
    stats = Hash.new { |h, k| h[k] = { points: 0, wins: 0, podiums: 0 } }
    standings.each do |ds|
      c = sd_index[ds.driver_id]&.constructor
      next unless c
      s = stats[c.id]
      s[:points] += ds.points || 0
      s[:wins] += ds.wins || 0
      s[:podiums] += (ds.second_places || 0) + (ds.third_places || 0) + (ds.wins || 0)
    end
    stats
  end
end
