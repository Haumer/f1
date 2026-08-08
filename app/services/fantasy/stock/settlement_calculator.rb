module Fantasy
  module Stock
    # Pure money math shared by SettleRace (live) and ReplayTransactions
    # (backfill). No DB writes — inputs come in, numbers come out.
    module SettlementCalculator
      DIVIDEND_BASE = 0.10
      DIVIDEND_SURPRISE_BONUS = 0.02
      CONSTRUCTOR_MULT_MIN = 0.5
      CONSTRUCTOR_MULT_MAX = 5.0
      BORROW_FEE_RATE = 0.0025 # 0.25% per race
      MAX_LOSS_MULTIPLIER = 2.0 # Auto-liquidate at 2x entry price loss
      DEFAULT_CONSTRUCTOR_POSITION = 5 # WCC P5 fallback

      module_function

      # Constructor multiplier: WCC P1 → 0.5, WCC P10 → 5.0 (linear).
      def constructor_multiplier_for_position(position)
        clamped = position.clamp(1, 10)
        CONSTRUCTOR_MULT_MIN + (clamped - 1) * ((CONSTRUCTOR_MULT_MAX - CONSTRUCTOR_MULT_MIN) / 9.0)
      end

      def default_constructor_multiplier
        constructor_multiplier_for_position(DEFAULT_CONSTRUCTOR_POSITION)
      end

      # Returns { per_share:, elo_rank:, overperformance: } for a top-10 finish.
      # per_share is 0 if the driver didn't finish top-10.
      def dividend_breakdown(constructor_mult:, elo_rank:, position:)
        return { per_share: 0.0, elo_rank: elo_rank, overperformance: 0 } unless position && position <= 10

        overperformance = [elo_rank - position, 0].max
        per_share = DIVIDEND_BASE * constructor_mult + DIVIDEND_SURPRISE_BONUS * overperformance
        { per_share: per_share, elo_rank: elo_rank, overperformance: overperformance }
      end

      def borrow_fee_per_share(entry_price:)
        entry_price * BORROW_FEE_RATE
      end

      def margin_call_price(entry_price:)
        entry_price * (1 + MAX_LOSS_MULTIPLIER)
      end

      # Build { driver_id => constructor_multiplier } for a race, based on the
      # prior season's final WCC standings. Returns {} if no prior standings.
      def constructor_multipliers_for_race(race)
        prev_season = race.season.previous_season
        return {} unless prev_season

        last_race = Race.where(season: prev_season).order(:round).last
        return {} unless last_race

        cs_pos = ConstructorStanding.where(race_id: last_race.id)
                                    .pluck(:constructor_id, :position).to_h
        SeasonDriver.where(season_id: race.season_id)
                    .pluck(:driver_id, :constructor_id)
                    .each_with_object({}) do |(driver_id, constructor_id), h|
          pos = cs_pos[constructor_id] || DEFAULT_CONSTRUCTOR_POSITION
          h[driver_id] = constructor_multiplier_for_position(pos)
        end
      end
    end
  end
end
