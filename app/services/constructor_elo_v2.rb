class ConstructorEloV2
  STARTING_ELO = 2000.0
  BASE_K = 32
  REFERENCE_RACES = 12.0

  # Run full historical simulation from scratch.
  # Ranks constructors by combined position_order of all their drivers (lower = better).
  def self.simulate_all!
    races = Race.includes(race_results: :constructor).order(:date, :round).to_a
    races_per_year = Race.group(:year).count

    elo = {}
    peak = {}

    race_result_updates = []
    constructor_updates = {}

    races.each do |race|
      results = race.race_results.select { |rr| rr.position_order.present? }
      next if results.empty?

      by_constructor = results.group_by(&:constructor_id)
      scores = by_constructor.map { |cid, rrs| [cid, rrs.sum(&:position_order), rrs] }
      next if scores.size < 2

      season_races = races_per_year[race.year] || REFERENCE_RACES.to_i
      scores.each { |cid, _, _| elo[cid] ||= STARTING_ELO }

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

    # Batch persist
    ActiveRecord::Base.transaction do
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

    { constructors_updated: constructor_updates.size, race_results_updated: race_result_updates.size }
  end

  # Process a single race (for incremental updates after sync)
  def self.process_race(race)
    results = race.race_results.includes(:constructor).select { |rr| rr.position_order.present? }
    return if results.empty?

    by_constructor = results.group_by(&:constructor_id)
    scores = by_constructor.map { |cid, rrs| [cid, rrs.sum(&:position_order), rrs] }
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
        new_peak = [constructor.peak_elo_v2 || 0, new_elo].max

        constructor.update!(elo_v2: new_elo, peak_elo_v2: new_peak)
        rrs.each { |rr| rr.update!(old_constructor_elo_v2: old_elo, new_constructor_elo_v2: new_elo) }
      end
    end
  end
end
