# Periodically re-validates recently-completed race results against Jolpica.
#
# SeasonSync.races_needing_update skips any race whose stored row count matches
# the expected driver count — so once 20 results are written, position swaps
# and post-race reclassifications (FIA penalties, retro-corrected timing) are
# never re-fetched on the normal sync hot path.
#
# This job bypasses that filter: it calls UpdateRaceResult directly on the last
# N completed races. The content-aware diff in maybe_reset_for_resync is a
# no-op when the signature matches, so each call is cheap when nothing drifted
# and triggers ResetRaceState + recompute when it did.
#
# Triggered by Heroku Scheduler. Recommended cadence: daily.
class RaceResultsSweepJob < ApplicationJob
  queue_as :default

  # Window large enough to catch most post-race reclassifications (FIA usually
  # publishes corrections within a week), small enough that one Jolpica call
  # per race per day is trivial.
  DEFAULT_LOOKBACK_RACES = 6

  def perform(lookback: DEFAULT_LOOKBACK_RACES)
    races = Race.where("date <= ?", Date.current)
                .where(cancelled: false)
                .order(date: :desc)
                .limit(lookback)

    races.each do |race|
      next if RaceResult.unscoped.where(race: race).empty? # nothing to compare against yet

      Rails.logger.info "[RaceResultsSweepJob] checking R#{race.round} #{race.year}"
      UpdateRaceResult.new(race: race).update_all
      sleep 1 # be polite to Jolpica
    rescue StandardError => e
      Rails.logger.error "[RaceResultsSweepJob] R#{race.round} #{race.year} failed: #{e.class}: #{e.message}"
    end
  end
end
