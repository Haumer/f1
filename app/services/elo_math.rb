module EloMath
  SCALE = 400.0

  def self.compute_k_pair(base_k, reference_races, season_races, n)
    base_k * (reference_races / season_races.to_f) / Math.sqrt(n - 1)
  end

  # participants: [{ id:, elo:, score: }, ...] where lower score = better
  # Returns: { id => adjustment }
  def self.pairwise_adjustments(participants, k_pair)
    adjustments = Hash.new(0.0)
    participants.combination(2) do |a, b|
      ea = 1.0 / (1 + 10**((b[:elo] - a[:elo]) / SCALE))
      actual = a[:score] < b[:score] ? 1.0 : (a[:score] == b[:score] ? 0.5 : 0.0)
      adjustments[a[:id]] += k_pair * (actual - ea)
      adjustments[b[:id]] += k_pair * ((1.0 - actual) - (1.0 - ea))
    end
    adjustments
  end
end
