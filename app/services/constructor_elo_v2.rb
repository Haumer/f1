class ConstructorEloV2
  STARTING_ELO = 2000.0
  BASE_K = 32
  REGRESSION_FACTOR = 0.03
  REFERENCE_RACES = 12.0
  SCALE = 400.0

  # Run full historical simulation from scratch.
  # Ranks constructors by combined position_order of all their drivers (lower = better).
  def self.simulate_all!
    races = Race.includes(race_results: :constructor).order(:date, :round).to_a
    races_per_year = Race.joins(:race_results).distinct.group(:year).count

    elo = {}
    peak = {}
    prev_year = nil

    race_result_updates = []
    constructor_updates = {}

    races.each do |race|
      year = race.year

      # Season-end regression
      if prev_year && year != prev_year
        elo.each { |cid, e| elo[cid] = e * (1 - REGRESSION_FACTOR) + STARTING_ELO * REGRESSION_FACTOR }
      end
      prev_year = year

      results = race.race_results.select { |rr| rr.position_order.present? }
      next if results.empty?

      # Group by constructor, compute combined position (sum of all drivers' position_order)
      by_constructor = results.group_by(&:constructor_id)
      constructor_scores = by_constructor.map do |cid, rrs|
        [cid, rrs.sum(&:position_order), rrs]
      end

      next if constructor_scores.size < 2

      season_races = races_per_year[year] || REFERENCE_RACES.to_i
      n = constructor_scores.size
      k_pair = BASE_K * (REFERENCE_RACES / season_races.to_f) / Math.sqrt(n - 1)

      constructor_scores.each { |cid, _, _| elo[cid] ||= STARTING_ELO }

      adjustments = Hash.new(0.0)
      constructor_scores.combination(2) do |(cid_a, score_a, _), (cid_b, score_b, _)|
        ra = elo[cid_a]
        rb = elo[cid_b]
        ea = 1.0 / (1 + 10**((rb - ra) / SCALE))

        # Lower combined score = better
        actual = score_a < score_b ? 1.0 : (score_a == score_b ? 0.5 : 0.0)

        adjustments[cid_a] += k_pair * (actual - ea)
        adjustments[cid_b] += k_pair * ((1.0 - actual) - (1.0 - ea))
      end

      # Apply adjustments and record per-race snapshots
      constructor_scores.each do |cid, _, rrs|
        old_elo = elo[cid]
        elo[cid] += adjustments[cid]
        peak[cid] = [peak[cid] || 0, elo[cid]].max

        constructor_updates[cid] = { elo_v2: elo[cid], peak_elo_v2: peak[cid] }

        # Store snapshot on every race_result for this constructor in this race
        rrs.each do |rr|
          race_result_updates << { id: rr.id, old_constructor_elo_v2: old_elo, new_constructor_elo_v2: elo[cid] }
        end
      end
    end

    # Batch persist
    ActiveRecord::Base.transaction do
      race_result_updates.each_slice(500) do |batch|
        batch.each do |update|
          RaceResult.where(id: update[:id]).update_all(
            old_constructor_elo_v2: update[:old_constructor_elo_v2],
            new_constructor_elo_v2: update[:new_constructor_elo_v2]
          )
        end
      end

      constructor_updates.each do |cid, attrs|
        Constructor.where(id: cid).update_all(attrs)
      end
    end

    { constructors_updated: constructor_updates.size, race_results_updated: race_result_updates.size }
  end

  # Process a single race (for incremental updates after sync)
  def self.process_race(race)
    results = race.race_results.includes(:constructor)
                  .select { |rr| rr.position_order.present? }
    return if results.empty?

    by_constructor = results.group_by(&:constructor_id)
    constructor_scores = by_constructor.map do |cid, rrs|
      [cid, rrs.sum(&:position_order), rrs]
    end

    return if constructor_scores.size < 2

    season_races = Race.where(year: race.year).count
    n = constructor_scores.size
    k_pair = BASE_K * (REFERENCE_RACES / season_races.to_f) / Math.sqrt(n - 1)

    all_constructors = Constructor.where(id: constructor_scores.map(&:first)).index_by(&:id)

    adjustments = Hash.new(0.0)
    constructor_scores.combination(2) do |(cid_a, score_a, _), (cid_b, score_b, _)|
      ra = all_constructors[cid_a].elo_v2 || STARTING_ELO
      rb = all_constructors[cid_b].elo_v2 || STARTING_ELO
      ea = 1.0 / (1 + 10**((rb - ra) / SCALE))

      actual = score_a < score_b ? 1.0 : (score_a == score_b ? 0.5 : 0.0)

      adjustments[cid_a] += k_pair * (actual - ea)
      adjustments[cid_b] += k_pair * ((1.0 - actual) - (1.0 - ea))
    end

    ActiveRecord::Base.transaction do
      constructor_scores.each do |cid, _, rrs|
        constructor = all_constructors[cid]
        old_elo = constructor.elo_v2 || STARTING_ELO
        new_elo = old_elo + (adjustments[cid] || 0)
        new_peak = [constructor.peak_elo_v2 || 0, new_elo].max

        constructor.update!(elo_v2: new_elo, peak_elo_v2: new_peak)

        rrs.each do |rr|
          rr.update!(old_constructor_elo_v2: old_elo, new_constructor_elo_v2: new_elo)
        end
      end
    end
  end

  # Apply season-end regression to all constructors with V2 ratings
  def self.apply_regression!
    Constructor.where.not(elo_v2: nil).find_each do |constructor|
      regressed = constructor.elo_v2 * (1 - REGRESSION_FACTOR) + STARTING_ELO * REGRESSION_FACTOR
      constructor.update!(elo_v2: regressed)
    end
  end
end
