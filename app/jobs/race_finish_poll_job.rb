class RaceFinishPollJob < ApplicationJob
  queue_as :default

  MAX_POLLS = 120 # Stop after 2 hours of polling (1/min)

  def perform(attempt: 1)
    season = Season.find_by(year: Date.current.year.to_s)
    return unless season

    race = season.next_race
    return unless race

    # Only poll if we're in the post-race window (2h after start)
    return unless race.starts_at && Time.current >= race.starts_at + 2.hours

    # Already synced?
    return if race.race_results.exists?

    # Try to pull results directly (Jolpica → Wikipedia). It's a no-op if no
    # source has published yet, so we just retry until they do.
    UpdateRaceResult.new(race: race).update_all

    if race.race_results.exists?
      Rails.logger.info "[RaceFinishPollJob] R#{race.round} results landed — running downstream sync"
      PostRaceSyncJob.perform_now
    elsif attempt < MAX_POLLS
      Rails.logger.info "[RaceFinishPollJob] R#{race.round} no results yet (attempt #{attempt}), retrying in 1 min"
      self.class.set(wait: 1.minute).perform_later(attempt: attempt + 1)
    else
      Rails.logger.info "[RaceFinishPollJob] R#{race.round} max polls reached, giving up"
    end
  end
end
