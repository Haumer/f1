class EloPredictionService
  # Uses the same V2 Elo formula to compute expected Elo changes
  # from a predicted finishing order.
  #
  # Returns: { driver_id => { old_elo:, new_elo:, diff: } }
  def self.compute(prediction)
    race = prediction.race
    results = prediction.predicted_results
    return {} if results.blank? || results.size < 2

    drivers = Driver.where(id: results.map { |r| r["driver_id"] }).index_by(&:id)
    sorted = results.sort_by { |r| r["position"] }

    season_races = race.season&.races&.count || Race.where(year: race.year).count

    participants = sorted.map do |r|
      did = r["driver_id"]
      { id: did, elo: drivers[did]&.elo_v2 || EloRatingV2::STARTING_ELO, score: r["position"] }
    end

    k_pair = EloMath.compute_k_pair(EloRatingV2::BASE_K, EloRatingV2::REFERENCE_RACES, season_races, sorted.size)
    adjustments = EloMath.pairwise_adjustments(participants, k_pair)

    adjustments.to_h do |did, adj|
      old = participants.find { |p| p[:id] == did }[:elo]
      [did.to_s, { "old_elo" => old.round(1), "new_elo" => (old + adj).round(1), "diff" => adj.round(1) }]
    end
  end
end
