module DriverCards
  # Smashes 3 cards of the same (user, driver, tier) into 1 card at the next tier.
  #
  # Rules:
  #   - Need exactly 3 source cards (oldest 3 picked).
  #   - Legendary can't combine further.
  #   - The new card occupies the most-recent contributor's race slot (so the
  #     unique (user, driver, race) index is satisfied within the same txn).
  #   - Snapshots + predicted/actual are copied from the most recent contributor;
  #     the new card is conceptually a "promotion" of that prediction.
  #   - earned_at = Time.current.
  #   - combined_from_race_ids stores the 3 source race_ids for the back-face
  #     receipt.
  class Combine
    REQUIRED_COUNT = 3

    class Error < StandardError; end

    def self.call(user:, driver:, tier:)
      new(user: user, driver: driver, tier: tier).call
    end

    def initialize(user:, driver:, tier:)
      @user = user
      @driver = driver
      @tier = tier.to_s
    end

    def call
      next_tier = DriverCard.next_tier(@tier)
      raise Error, "#{@tier} can't be combined further" unless next_tier

      sources = candidate_sources.order(:earned_at).limit(REQUIRED_COUNT).to_a
      raise Error, "need #{REQUIRED_COUNT} #{@tier} cards, have #{sources.size}" if sources.size < REQUIRED_COUNT

      target = sources.max_by(&:earned_at)
      source_race_ids = sources.map(&:race_id)

      DriverCard.transaction do
        sources.each(&:destroy!)
        DriverCard.create!(
          user: @user,
          driver: @driver,
          race: target.race,
          predicted_position: target.predicted_position,
          actual_position: target.actual_position,
          tier: next_tier,
          snapshot_wins: target.snapshot_wins,
          snapshot_podiums: target.snapshot_podiums,
          snapshot_wdc: target.snapshot_wdc,
          snapshot_elo: target.snapshot_elo,
          earned_at: Time.current,
          combined_from_race_ids: source_race_ids
        )
      end
    end

    private

    def candidate_sources
      DriverCard.where(user: @user, driver: @driver, tier: @tier)
    end
  end
end
