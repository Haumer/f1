# Reverts every piece of state derived from a single race so it can be re-synced
# cleanly. Used by UpdateRaceResult when a source publishes a different result
# set than what we already stored (the partial -> complete transition that
# bit us at R6 Monaco 2026).
#
# Resets:
#   * Driver.elo_v2 / peak_elo_v2 — re-derived from race_result history before this race
#   * Constructor.elo_v2 / peak_elo_v2 — same
#   * Deletes: race_results, driver_standings, fantasy_stock_transactions
#       (dividend/borrow_fee/liquidation/pick_reward), stock_price_snapshots,
#       fantasy_snapshots for the race
#   * Nulls RacePick.score for the race
#
# Wallet cash is rebuilt on next ReplayTransactions run (which is what
# PostRaceSyncJob does after re-sync).
class ResetRaceState
    DELETABLE_STOCK_TXN_KINDS = %w[dividend borrow_fee liquidation pick_reward].freeze

    def initialize(race:)
        @race = race
    end

    def call
        ActiveRecord::Base.transaction do
            reset_elo(:driver_id, :new_elo_v2, Driver, EloRatingV2::STARTING_ELO)
            reset_elo(:constructor_id, :new_constructor_elo_v2, Constructor, ConstructorEloV2::STARTING_ELO)
            wipe_derived_state
        end
    end

    private

    # Walk every race_result strictly before @race.date, set the entity's
    # elo_v2 to the most recent value and peak_elo_v2 to the historical max.
    # Entities with no prior history reset to starting.
    def reset_elo(entity_col, elo_col, model, starting_value)
        latest, peak = {}, {}
        RaceResult.unscoped.joins(:race)
            .where("races.date < ?", @race.date)
            .where.not(elo_col => nil)
            .order("races.date asc")
            .pluck("race_results.#{entity_col}", "race_results.#{elo_col}")
            .each do |id, e|
                latest[id] = e
                peak[id]   = [peak[id] || 0, e].max
            end

        affected = RaceResult.unscoped.where(race: @race).pluck(entity_col).uniq.compact
        affected.each do |id|
            model.where(id: id).update_all(
                elo_v2: latest[id] || starting_value,
                peak_elo_v2: peak[id] || starting_value
            )
        end
    end

    def wipe_derived_state
        RaceResult.unscoped.where(race: @race).delete_all
        DriverStanding.where(race: @race).delete_all
        FantasyStockTransaction.where(race: @race, kind: DELETABLE_STOCK_TXN_KINDS).delete_all
        StockPriceSnapshot.where(race: @race).delete_all if defined?(StockPriceSnapshot)
        FantasySnapshot.where(race: @race).delete_all if defined?(FantasySnapshot)
        RacePick.where(race: @race).update_all(score: nil)
    end
end
