module Fantasy
  # Scores users' race-position predictions against the actual finishing order
  # and pays the credit reward into their wallet.
  #
  # Picks are a full-grid prediction: [{ "driver_id" => N, "position" => P }, ...].
  # Each correctly-ish placed driver earns points by how close the prediction was
  # to the real finishing position (RaceResult#position_order), with a bonus for a
  # perfectly-called podium. Points convert to credits at CREDITS_PER_POINT.
  #
  # The reward credits the wallet (FantasyPortfolio#cash) and is recorded as a
  # FantasyStockTransaction (kind: "pick_reward") so it appears in the unified
  # transaction ledger AND survives ReplayTransactions#replay_cash, which rebuilds
  # wallet cash by summing every transaction. This mirrors how dividends work.
  #
  # Idempotent: re-running always recomputes RacePick#score, but only pays the
  # reward once per portfolio per race.
  class ScoreRacePicks
    # Points per driver by absolute distance between predicted and actual position.
    POINTS_BY_DISTANCE = { 0 => 25, 1 => 15, 2 => 10, 3 => 5 }.freeze
    PERFECT_PODIUM_BONUS = 25
    CREDITS_PER_POINT = 2.0

    def initialize(race:)
      @race = race
    end

    def call
      return unless @race.race_results.exists?

      finish_by_driver = RaceResult.where(race: @race)
                                   .where.not(position_order: nil)
                                   .pluck(:driver_id, :position_order)
                                   .to_h

      RacePick.where(race: @race).find_each do |pick|
        score = score_pick(pick, finish_by_driver)
        pick.update_column(:score, score) unless pick.score == score

        next if score <= 0

        award_credits(pick, score)
      end
    end

    private

    def score_pick(pick, finish_by_driver)
      placed = pick.placed_drivers
      total = placed.sum do |p|
        actual = finish_by_driver[p["driver_id"]]
        next 0 unless actual

        POINTS_BY_DISTANCE.fetch((actual - p["position"]).abs, 0)
      end
      total + (perfect_podium?(placed, finish_by_driver) ? PERFECT_PODIUM_BONUS : 0)
    end

    def perfect_podium?(placed, finish_by_driver)
      podium = placed.select { |p| p["position"] <= 3 }
      return false if podium.size < 3

      podium.all? { |p| finish_by_driver[p["driver_id"]] == p["position"] }
    end

    def award_credits(pick, score)
      wallet = FantasyPortfolio.find_by(user_id: pick.user_id, season_id: @race.season_id)
      stock  = FantasyStockPortfolio.find_by(user_id: pick.user_id, season_id: @race.season_id)
      return unless wallet && stock

      # Pay once per portfolio per race.
      return if stock.transactions.where(race: @race, kind: "pick_reward").exists?

      credits = (score * CREDITS_PER_POINT).round(2)

      ActiveRecord::Base.transaction do
        wallet.lock!
        wallet.update!(cash: wallet.cash + credits)
        stock.transactions.create!(
          kind: "pick_reward",
          race: @race,
          amount: credits,
          note: "Race picks: #{score} pts (#{@race.circuit.name})"
        )
      end
    end
  end
end
