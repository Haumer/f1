class ConstructorsController < ApplicationController
  def index
    @active_constructors = Constructor.where(active: true).order(:name)
    @historical_constructors = Constructor.where(active: [false, nil])
      .joins(:race_results)
      .select("constructors.*, COUNT(DISTINCT race_results.race_id) as race_count")
      .group("constructors.id")
      .having("COUNT(DISTINCT race_results.race_id) >= 10")
      .order("race_count DESC")
  end

  def grid
    season = current_season
    lineup_season = SeasonDriver.where(season: season).exists? ? season : season.previous_season
    @season_year = season.year

    @team_grid = Constructor.where(active: true).order(:name).filter_map do |constructor|
      drivers = SeasonDriver.where(season: lineup_season, constructor: constructor, standin: [false, nil])
                  .includes(driver: :countries).map(&:driver).uniq
      next if drivers.empty?
      { constructor: constructor, drivers: drivers }
    end
  end

  def show
    @constructor = Constructor.includes(
      race_results: { race: :circuit, driver: [:countries] },
      season_drivers: { driver: [:countries], season: [] }
    ).find(params[:id])
    set_constructor_accent(@constructor)

    results = @constructor.race_results.to_a
    @total_races = results.map(&:race_id).uniq.size
    @race_wins = results.count { |rr| rr.position_order == 1 }
    @podiums = results.count { |rr| rr.position_order && rr.position_order <= 3 }

    # Constructor championship wins (position 1 at season-end races)
    season_end_race_ids = Race.where(season_end: true).pluck(:id)
    @championship_wins = @constructor.constructor_standings
      .where(race_id: season_end_race_ids, position: 1).count

    # Driver roster grouped by season (most recent first)
    @roster_by_season = @constructor.season_drivers
      .includes(:driver, :season)
      .group_by(&:season)
      .sort_by { |season, _| -season.year.to_i }
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
    # Group season_drivers by (season, constructor) to find teammates
    grouped = SeasonDriver.where(standin: [false, nil])
                 .joins(:season).where("seasons.year >= '1990'")
                 .includes(:driver, :season, :constructor)
                 .group_by { |sd| [sd.season_id, sd.constructor_id] }

    # Pre-load race results only for drivers in pairings
    pairing_driver_ids = grouped.values.flat_map { |sds| sds.map(&:driver_id) }.uniq
    pairing_season_ids = grouped.keys.map(&:first).uniq
    all_results = RaceResult.where(driver_id: pairing_driver_ids)
                 .joins(:race).where(races: { season_id: pairing_season_ids })
                 .index_by { |rr| [rr.race_id, rr.driver_id] }
    races_by_season = Race.where(season_id: pairing_season_ids)
                 .joins(:race_results).distinct.group_by(&:season_id)

    seen_pairs = Set.new
    @pairings = []

    grouped.each do |(_season_id, constructor_id), sds|
      drivers = sds.map(&:driver).uniq(&:id)
      next if drivers.size < 2
      season = sds.first.season
      constructor = sds.first.constructor

      drivers.combination(2).each do |d1, d2|
        pair_key = [d1.id, d2.id].sort
        next if seen_pairs.include?(pair_key)
        seen_pairs << pair_key

        # Find all seasons they were teammates
        shared = grouped.select do |(_sid, _cid), group_sds|
          ids = group_sds.map(&:driver_id)
          ids.include?(d1.id) && ids.include?(d2.id)
        end

        constructors = shared.map { |(_sid, _cid), group_sds| group_sds.first.constructor }.uniq(&:id)

        # Calculate race stats across all shared seasons
        races_together = 0
        wins = 0
        one_two_finishes = 0

        shared.each do |(sid, _cid), _group_sds|
          season_races = races_by_season[sid] || []
          season_races.each do |race|
            rr1 = all_results[[race.id, d1.id]]
            rr2 = all_results[[race.id, d2.id]]
            next unless rr1 && rr2

            races_together += 1
            p1 = rr1.position_order
            p2 = rr2.position_order
            wins += 1 if p1 == 1 || p2 == 1
            one_two_finishes += 1 if p1 && p2 && [p1, p2].sort == [1, 2]
          end
        end

        next if races_together < 5 # minimum threshold

        @pairings << {
          driver1: d1,
          driver2: d2,
          constructors: constructors,
          seasons_together: shared.map { |(_sid, _cid), group_sds| group_sds.first.season }.uniq(&:id).sort_by(&:year),
          races_together: races_together,
          wins: wins,
          win_pct: (wins.to_f / races_together * 100).round(1),
          one_two_finishes: one_two_finishes,
          one_two_pct: (one_two_finishes.to_f / races_together * 100).round(1)
        }
      end
    end

    @pairings.sort_by! { |p| [-p[:one_two_pct], -p[:win_pct], -p[:races_together]] }
    @pairings = @pairings.first(50)
  end

  def families
    @lineages = Constructor.lineages
    @families = Constructor.all_families_with_constructors
    # Pre-load all constructors referenced in lineages to avoid N+1
    all_refs = @lineages.values.flat_map { |info| info[:chain] }
    @constructors_by_ref = Constructor.where(constructor_ref: all_refs).index_by(&:constructor_ref)
  end
end
