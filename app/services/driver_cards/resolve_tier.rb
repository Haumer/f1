module DriverCards
  # Pure function: given a prediction outcome, returns the card tier.
  #
  # Earn rules (no card at all if predicted != actual):
  #   P4–10 correct                        → guaranteed Bronze   (10% rolls Silver)
  #   P2 or P3 correct                     → guaranteed Silver   (10% rolls Gold)
  #   P1 correct                           → guaranteed Gold     (10% rolls Platinum)
  #   P1 correct AND grid > P5 (upset)     → guaranteed Platinum (10% rolls Legendary)
  #
  # RNG is injectable so the bump rolls can be tested deterministically and so
  # pity-protect can plug in later by passing a biased RNG.
  class ResolveTier
    BUMP_PROBABILITY = 0.10
    UPSET_GRID_THRESHOLD = 5 # grid worse than this + P1 finish counts as an upset

    BASE_TIER_BY_PREDICTED = {
      1  => :p1,
      2  => :podium, 3 => :podium,
      4  => :points, 5 => :points, 6 => :points, 7 => :points,
      8  => :points, 9 => :points, 10 => :points
    }.freeze

    TIER_LADDER = {
      points: %w[bronze silver],
      podium: %w[silver gold],
      p1:     %w[gold platinum],
      upset:  %w[platinum legendary]
    }.freeze

    # Returns one of TIERS, or nil if this prediction doesn't earn a card.
    def self.call(predicted:, actual:, grid:, rng: Random.new)
      return nil unless predicted && actual && predicted == actual

      category = BASE_TIER_BY_PREDICTED[predicted]
      return nil unless category # outside 1..10 finishes don't earn

      # Upset overrides the p1 category when the grid was outside the top 5.
      category = :upset if category == :p1 && grid && grid > UPSET_GRID_THRESHOLD

      guaranteed, bumped = TIER_LADDER[category]
      rng.rand < BUMP_PROBABILITY ? bumped : guaranteed
    end
  end
end
