module Fantasy
  # Scores users' race-position predictions against the actual finishing order
  # and pays the credit reward into their wallet.
  #
  # Picks are a full-grid prediction: [{ "driver_id" => N, "position" => P }, ...].
  # Each correctly-ish placed driver earns points by how close the prediction was
  # to the real finishing position (RaceResult#position_order), with a bonus for a
  # perfectly-called podium. Points ARE credits — the score is paid out 1:1.
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
    # Points are paid out as credits 1:1 (no separate conversion rate).
    POINTS_BY_DISTANCE = { 0 => 50, 1 => 30, 2 => 20, 3 => 10 }.freeze
    PERFECT_PODIUM_BONUS = 50

    # Scoring cutoff: predictions outside the top SCORING_TOP_N positions score
    # zero. Matches DriverCards::ResolveTier::CARD_ELIGIBLE_MAX so the "no card"
    # zone is also a "no points" zone — one rule, one signal.
    SCORING_TOP_N = 10
    # The cutoff is forward-only: races before RULE_EFFECTIVE_DATE keep the
    # original "every distance scores" behavior so historical leaderboard ranks
    # and wallet credits don't shift retroactively.
    RULE_EFFECTIVE_DATE = Date.new(2026, 6, 29)

    # Returns the scoring_limit to apply for this race (nil = no limit).
    def self.scoring_limit_for(race)
      return nil unless race&.date && race.date >= RULE_EFFECTIVE_DATE
      SCORING_TOP_N
    end

    # One scored prediction: the driver, where you placed them, where they
    # actually finished (nil if no classified result), and the points earned.
    # out_of_zone is true when the predicted position was beyond scoring_limit
    # for this race — the row counted as a hit but earned zero points.
    Row = Struct.new(:driver_id, :predicted, :actual, :points, :out_of_zone, keyword_init: true) do
      def hit?   = actual && predicted == actual
      def scored? = points.positive?
    end

    # Pure scoring of a set of placements against a finishing order. Shared by the
    # settler (which only needs the total) and the scorecard view (which renders
    # every row), so the displayed breakdown can never drift from the paid score.
    #
    #   placed           -> [{ "driver_id" => N, "position" => P }, ...]
    #   finish_by_driver -> { driver_id => position_order }
    #   scoring_limit:   -> max predicted position eligible for points (nil = all)
    #
    # Returns { rows:, podium_bonus:, total:, exact: }.
    def self.breakdown(placed, finish_by_driver, scoring_limit: nil)
      rows = placed.map do |p|
        actual = finish_by_driver[p["driver_id"]]
        out_of_zone = scoring_limit && p["position"] > scoring_limit
        points = if out_of_zone || actual.nil?
          0
        else
          POINTS_BY_DISTANCE.fetch((actual - p["position"]).abs, 0)
        end
        Row.new(driver_id: p["driver_id"], predicted: p["position"], actual: actual,
                points: points, out_of_zone: !!out_of_zone)
      end
      podium_bonus = perfect_podium?(placed, finish_by_driver) ? PERFECT_PODIUM_BONUS : 0

      {
        rows: rows,
        podium_bonus: podium_bonus,
        total: rows.sum(&:points) + podium_bonus,
        exact: rows.count(&:hit?),
      }
    end

    def self.perfect_podium?(placed, finish_by_driver)
      podium = placed.select { |p| p["position"] <= 3 }
      return false if podium.size < 3

      podium.all? { |p| finish_by_driver[p["driver_id"]] == p["position"] }
    end

    def initialize(race:)
      @race = race
    end

    def call
      return unless @race.race_results.exists?

      finish_by_driver = RaceResult.where(race: @race)
                                   .where.not(position_order: nil)
                                   .pluck(:driver_id, :position_order)
                                   .to_h

      limit = self.class.scoring_limit_for(@race)
      RacePick.where(race: @race).find_each do |pick|
        score = self.class.breakdown(pick.placed_drivers, finish_by_driver, scoring_limit: limit)[:total]
        pick.update_column(:score, score) unless pick.score == score

        next if score <= 0

        award_credits(pick, score)
      end

      # Layer 1 of the driver-card system: manually-placed picks whose predicted
      # position matches the actual finish earn a DriverCard. AwardForRace is
      # idempotent (unique index on user+driver+race), so re-running
      # ScoreRacePicks doesn't re-award.
      DriverCards::AwardForRace.new(race: @race).call
    end

    private

    def award_credits(pick, score)
      wallet = FantasyPortfolio.find_by(user_id: pick.user_id, season_id: @race.season_id)
      stock  = FantasyStockPortfolio.find_by(user_id: pick.user_id, season_id: @race.season_id)
      return unless wallet && stock

      # Pay once per portfolio per race. Points are credited 1:1.
      return if stock.transactions.where(race: @race, kind: "pick_reward").exists?

      ActiveRecord::Base.transaction do
        wallet.lock!
        wallet.update!(cash: wallet.cash + score)
        stock.transactions.create!(
          kind: "pick_reward",
          race: @race,
          amount: score,
          note: "Race picks: #{score} pts (#{@race.circuit.name})"
        )
      end
    end
  end
end
