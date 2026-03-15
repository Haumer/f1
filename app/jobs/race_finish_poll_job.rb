class RaceFinishPollJob < ApplicationJob
  queue_as :default

  MAX_POLLS = 120 # Stop after 2 hours of polling (1/min)

  def perform(attempt: 1)
    season = Season.find_by(year: Date.current.year.to_s)
    return unless season

    race = season.next_race
    return unless race # No pending race

    # Only poll if we're in the post-race window (2h after start)
    return unless race.starts_at && Time.current >= race.starts_at + 2.hours

    # Already synced?
    return if race.race_results.exists?

    # Check OpenF1
    if SeasonSync.race_confirmed_finished?(race)
      Rails.logger.info "[RaceFinishPollJob] R#{race.round} confirmed finished, triggering sync"
      PostRaceSyncJob.perform_later
    elsif attempt < MAX_POLLS
      # Re-check in 1 minute
      self.class.set(wait: 1.minute).perform_later(attempt: attempt + 1)
    end
  end
end
