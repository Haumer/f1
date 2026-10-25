# Polls for a race's qualifying classification once the session should have
# ended, every POLL_INTERVAL, until a source publishes it or POLL_WINDOW has
# passed since the session started. If the window closes without a complete
# classification, an AdminAlert flags it for manual follow-up.
#
# Started by `rake f1:qualifying_sync` (hourly, Heroku Scheduler), which also
# guards against stacking a second chain on the same race.
class QualifyingSyncJob < ApplicationJob
  include Alertable

  queue_as :default

  SESSION_LENGTH = 1.hour   # when to start looking, measured from quali start
  POLL_INTERVAL  = 2.minutes
  POLL_WINDOW    = 24.hours # give up and alert this long after quali start

  class << self
    def poll_opens_at(race)
      race.quali_starts_at&.+(SESSION_LENGTH)
    end

    def poll_deadline(race)
      race.quali_starts_at&.+(POLL_WINDOW)
    end

    # How many rows a complete classification should have. The season's
    # driver list over-counts (mid-season replacements stay listed), so use
    # the grid size of the most recent race that has results.
    def expected_grid_size(race)
      previous = race.season.races.where("round < ?", race.round)
                     .joins(:race_results).order(round: :desc).first
      return previous.race_results.count if previous

      active = race.season.season_drivers.where(active: true).count
      active.positive? ? active : race.season.season_drivers.count
    end

    def complete?(race)
      race.qualifying_results.count >= expected_grid_size(race)
    end

    # True while a poll chain is executing or scheduled. Defensive: any
    # failure (queue tables absent in some environments) reads as "not polling".
    def polling?
      return false unless defined?(SolidQueue::Job)

      SolidQueue::Job.where(class_name: name, finished_at: nil).exists?
    rescue StandardError => e
      Rails.logger.warn "[QualifyingSyncJob] polling? check failed: #{e.message}"
      false
    end
  end

  def perform(race_id:, attempt: 1)
    # with_cancelled so a race cancelled after this job was enqueued resolves to
    # the record (instead of raising under the default scope); we then skip it.
    race = Race.with_cancelled.find_by(id: race_id)
    return if race.nil? || race.cancelled?
    return if self.class.complete?(race)

    expected = self.class.expected_grid_size(race)
    updater = UpdateQualifyingResult.new(race: race)
    count = updater.call
    label = "R#{race.round} #{race.year} #{race.circuit&.name}"

    if count >= expected
      Rails.logger.info "[QualifyingSyncJob] #{label}: #{count} qualifying results from #{updater.source} (attempt #{attempt})"
      return
    end

    deadline = self.class.poll_deadline(race)
    if deadline.nil? || Time.current < deadline
      Rails.logger.info "[QualifyingSyncJob] #{label}: #{count}/#{expected} results (attempt #{attempt}), retrying in #{POLL_INTERVAL.inspect}"
      self.class.set(wait: POLL_INTERVAL).perform_later(race_id: race_id, attempt: attempt + 1)
    else
      Rails.logger.warn "[QualifyingSyncJob] #{label}: window closed with #{count}/#{expected} results after #{attempt} attempts, alerting"
      flag_missing(race, label, count, expected, attempt)
    end
  end

  private

  def flag_missing(race, label, count, expected, attempt)
    status = count.zero? ? "No qualifying results" : "Only #{count} of #{expected} qualifying results"
    AdminAlert.create!(
      title: "Qualifying results missing: #{label}",
      message: <<~MSG.strip,
        #{status} stored #{POLL_WINDOW.inspect} after qualifying started (#{race.quali_starts_at&.utc}).
        Polled Jolpica and Wikipedia #{attempt} times. Expected #{expected} rows (grid size of the previous race).
        Jolpica: #{UpdateQualifyingResult::ENDPOINT}/#{race.year}/#{race.round}/qualifying.json
        Wikipedia: #{race.url.presence || 'no article URL on the race'}
        Once a source has it: heroku run rake f1:qualifying YEAR=#{race.year}
      MSG
      severity: "warning",
      source: self.class.name
    )
  end
end
