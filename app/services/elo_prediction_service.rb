class EloPredictionService
  # Uses the same V2 Elo formula to compute expected Elo changes
  # from a predicted finishing order.
  #
  # Returns: { driver_id => { old_elo:, new_elo:, diff: } }
  def self.compute(prediction)
    race = prediction.race
    results = prediction.predicted_results
    return {} if results.blank? || results.size < 2

    # Load current Elo for all predicted drivers
    driver_ids = results.map { |r| r["driver_id"] }
    drivers = Driver.where(id: driver_ids).index_by(&:id)

    # Sort by predicted position
    sorted = results.sort_by { |r| r["position"] }

    # Use real V2 parameters
    season_races = Race.joins(:race_results).distinct.where(year: race.year).count
    season_races = EloRatingV2::REFERENCE_RACES.to_i if season_races == 0
    n = sorted.size
    k_pair = EloRatingV2::BASE_K * (EloRatingV2::REFERENCE_RACES / season_races.to_f) / Math.sqrt(n - 1)

    # Build elo lookup
    elo = {}
    sorted.each do |r|
      did = r["driver_id"]
      elo[did] = drivers[did]&.elo_v2 || EloRatingV2::STARTING_ELO
    end

    # Pairwise comparisons — identical to EloRatingV2
    adjustments = Hash.new(0.0)
    sorted.combination(2) do |a, b|
      did_a = a["driver_id"]
      did_b = b["driver_id"]
      ra = elo[did_a]
      rb = elo[did_b]
      ea = 1.0 / (1 + 10**((rb - ra) / EloRatingV2::SCALE))
      adjustments[did_a] += k_pair * (1.0 - ea)
      adjustments[did_b] += k_pair * (0.0 - (1.0 - ea))
    end

    # Build result hash
    changes = {}
    adjustments.each do |did, adj|
      old = elo[did]
      new_elo = old + adj
      changes[did.to_s] = {
        "old_elo" => old.round(1),
        "new_elo" => new_elo.round(1),
        "diff" => adj.round(1)
      }
    end

    changes
  end
end
