class ConstructorEloV2
  STARTING_ELO = 2000.0
  BASE_K = 32
  REFERENCE_RACES = 12.0
  SCORING_METHOD = "average finishing position"

  # Run full historical simulation from scratch.
  # Ranks constructors by average finishing position (lower = better), so teams
  # with different entry counts are compared on the same scale.
  def self.simulate_all!(persist: true)
    races = Race.includes(race_results: :constructor).order(:date, :round).to_a
    races_per_year = Race.group(:year).count

    elo = {}
    peak = {}

    race_result_updates = []
    constructor_updates = {}

    races.each do |race|
      results = race.race_results.select { |rr| rr.position_order.present? }
      next if results.empty?

      scores = constructor_scores(results)
      next if scores.size < 2

      season_races = races_per_year[race.year] || REFERENCE_RACES.to_i
      scores.each do |cid, _, _|
        elo[cid] ||= STARTING_ELO
        peak[cid] ||= STARTING_ELO
      end

      participants = scores.map { |cid, score, _| { id: cid, elo: elo[cid], score: score } }
      k_pair = EloMath.compute_k_pair(BASE_K, REFERENCE_RACES, season_races, scores.size)
      adjustments = EloMath.pairwise_adjustments(participants, k_pair)

      scores.each do |cid, _, rrs|
        old_elo = elo[cid]
        elo[cid] += adjustments[cid]
        peak[cid] = [peak[cid] || 0, elo[cid]].max
        constructor_updates[cid] = { elo_v2: elo[cid], peak_elo_v2: peak[cid] }
        rrs.each { |rr| race_result_updates << { id: rr.id, old: old_elo, new: elo[cid] } }
      end
    end

    result = { constructors_updated: constructor_updates.size, race_results_updated: race_result_updates.size }
    return result unless persist

    # Batch persist
    ActiveRecord::Base.transaction do
      # A full simulation is also the repair path after a scoring change. Clear
      # derived values first so cancelled/unclassified races and constructors
      # with no valid result cannot retain ratings from the previous formula.
      RaceResult.update_all(old_constructor_elo_v2: nil, new_constructor_elo_v2: nil)
      Constructor.update_all(elo_v2: nil, peak_elo_v2: nil)

      race_result_updates.each_slice(500) do |batch|
        batch.each do |update|
          RaceResult.where(id: update[:id]).update_all(
            old_constructor_elo_v2: update[:old], new_constructor_elo_v2: update[:new]
          )
        end
      end

      constructor_updates.each do |cid, attrs|
        Constructor.where(id: cid).update_all(attrs)
      end
    end

    result
  end

  # Process a single race (for incremental updates after sync)
  # Idempotent: skips if elo was already computed for this race.
  def self.process_race(race)
    results = race.race_results.includes(:constructor).select { |rr| rr.position_order.present? }
    return if results.empty?

    # Skip if already processed
    return if results.first.old_constructor_elo_v2.present?

    scores = constructor_scores(results)
    return if scores.size < 2

    season_races = race.season&.races&.count || Race.where(year: race.year).count
    all_constructors = Constructor.where(id: scores.map(&:first)).index_by(&:id)

    participants = scores.map { |cid, score, _| { id: cid, elo: all_constructors[cid].elo_v2 || STARTING_ELO, score: score } }
    k_pair = EloMath.compute_k_pair(BASE_K, REFERENCE_RACES, season_races, scores.size)
    adjustments = EloMath.pairwise_adjustments(participants, k_pair)

    ActiveRecord::Base.transaction do
      scores.each do |cid, _, rrs|
        constructor = all_constructors[cid]
        old_elo = constructor.elo_v2 || STARTING_ELO
        new_elo = old_elo + (adjustments[cid] || 0)
        new_peak = [constructor.peak_elo_v2 || old_elo, old_elo, new_elo].max

        constructor.update!(elo_v2: new_elo, peak_elo_v2: new_peak)
        rrs.each { |rr| rr.update!(old_constructor_elo_v2: old_elo, new_constructor_elo_v2: new_elo) }
      end
    end
  end

  def self.constructor_scores(results)
    results.group_by(&:constructor_id).filter_map do |constructor_id, constructor_results|
      next unless constructor_id

      average_finish = constructor_results.sum(&:position_order).fdiv(constructor_results.size)
      [constructor_id, average_finish, constructor_results]
    end
  end
  private_class_method :constructor_scores
end
