module DriverCards
  # For one race: walk every user's RacePick, find manually-placed drivers whose
  # predicted position matches the actual finishing position, and award a
  # DriverCard per match. Idempotent — the unique index on
  # (user_id, driver_id, race_id) means re-running this for the same race is a
  # no-op for already-earned cards.
  #
  # Random-source picks (auto-fill) never earn — only manual ones count, so the
  # collection reflects user judgement, not lucky defaults.
  class AwardForRace
    def initialize(race:, rng: Random.new)
      @race = race
      @rng = rng
    end

    def call
      return [] unless @race.race_results.exists?

      finish_by_driver = RaceResult.where(race: @race)
                                   .where.not(position_order: nil)
                                   .pluck(:driver_id, :position_order, :grid)
                                   .to_h { |did, pos, grid| [did, { actual: pos, grid: grid&.to_i }] }

      awarded = []

      RacePick.where(race: @race).find_each do |pick|
        pick.manual_picks.each do |p|
          driver_id = p["driver_id"]
          predicted = p["position"].to_i
          finish = finish_by_driver[driver_id]
          next unless finish

          tier = ResolveTier.call(
            predicted: predicted,
            actual: finish[:actual],
            grid: finish[:grid],
            rng: @rng
          )
          next unless tier

          card = DriverCard.find_or_initialize_by(
            user_id: pick.user_id,
            driver_id: driver_id,
            race_id: @race.id
          )
          next if card.persisted? # already awarded — idempotent skip

          driver = Driver.find(driver_id)
          card.assign_attributes(
            predicted_position: predicted,
            actual_position: finish[:actual],
            tier: tier,
            snapshot_wins: driver.wins || 0,
            snapshot_podiums: driver.podiums || 0,
            snapshot_wdc: career_championships(driver),
            snapshot_elo: driver.elo_v2,
            earned_at: Time.current
          )
          card.save!
          awarded << card
        end
      end

      awarded
    end

    private

    # Career WDC count = end-of-season standings where this driver finished P1.
    # Cheap denormalized lookup, no traversal of every season.
    def career_championships(driver)
      DriverStanding.where(driver_id: driver.id, position: 1, season_end: true).count
    end
  end
end
