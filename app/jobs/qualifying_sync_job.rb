class QualifyingSyncJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 3
  RETRY_DELAY = 30.minutes

  def perform(race_id:, attempt: 1)
    # with_cancelled so a race cancelled after this job was enqueued resolves to
    # the record (instead of raising under the default scope); we then skip it.
    race = Race.with_cancelled.find_by(id: race_id)
    return if race.nil? || race.cancelled?

    expected = race.season.season_drivers.count

    # Skip if qualifying already looks complete
    existing = race.qualifying_results.count
    return if existing >= expected

    count = UpdateQualifyingResult.new(race: race).call
    Rails.logger.info "[QualifyingSyncJob] Race #{race_id}: fetched #{count || 0} qualifying results (attempt #{attempt}, expected #{expected})"

    return unless count

    # If we got fewer than expected and have retries left, schedule a follow-up
    if count < expected && attempt < MAX_RETRIES
      Rails.logger.info "[QualifyingSyncJob] Incomplete data (#{count}/#{expected}), scheduling retry #{attempt + 1}"
      self.class.set(wait: RETRY_DELAY).perform_later(race_id: race_id, attempt: attempt + 1)
    end
  end
end
