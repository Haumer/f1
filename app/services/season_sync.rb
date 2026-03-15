require 'json'
require 'open-uri'

class SeasonSync
    STATUSES_ENDPOINT = "https://api.jolpi.ca/ergast/f1/status.json?limit=200"
    OPENF1_SESSIONS = "https://api.openf1.org/v1/sessions"
    RACE_BUFFER = 2.hours

    def initialize(year: Date.current.year)
        @year = year
    end

    def sync
        ensure_statuses
        season = UpdateSeason.new(year: @year).create_season
        return unless season

        sync_session_results(season)
        update_race_results(season)
        season.reload
    end

    # Check if the current season data is stale (new race results available)
    def self.stale?
        season = Season.find_by(year: Date.current.year.to_s)
        return true unless season

        # Race results missing for finished races
        races_needing_update = season.races
                                          .where(race_likely_finished_condition)
                                          .left_joins(:race_results)
                                          .where(race_results: { id: nil })
        return true if races_needing_update.exists?

        # Session data (qualifying/sprint) missing for current weekend
        session_data_stale?(season)
    end

    # Light check — only sync if stale, with cooldown to avoid hammering the API
    def self.sync_if_stale!
        return unless stale?
        return if recently_synced?

        new(year: Date.current.year).sync
        Rails.cache.write("season_sync:last_run", Time.current, expires_in: 1.hour)
    end

    private

    def ensure_statuses
        return if Status.count > 0

        puts "Fetching statuses..."
        data = JSON.parse(URI.open(STATUSES_ENDPOINT, read_timeout: 30).read)
        statuses = data.dig("MRData", "StatusTable", "Status") || []

        statuses.each do |s|
            Status.find_or_create_by(kaggle_id: s["statusId"].to_i) do |status|
                status.status_type = s["status"]
            end
        end
    rescue OpenURI::HTTPError, Timeout::Error, JSON::ParserError => e
        puts "Error fetching statuses: #{e.message}"
    end

    # Sync qualifying and sprint results for the current weekend race
    # (these sessions happen before the main race)
    def sync_session_results(season)
        today = Date.current
        # Find races in the current weekend window (FP1 is date-2, race is date)
        weekend_race = season.races
                             .where("date - 2 <= ? AND date >= ?", today, today)
                             .first
        return unless weekend_race

        # Qualifying: sync if quali date has passed and we don't have results
        if weekend_race.quali_date && weekend_race.quali_date <= today && weekend_race.qualifying_results.empty?
            puts "Syncing qualifying for R#{weekend_race.round}..."
            UpdateQualifyingResult.new(race: weekend_race).call
            sleep 1
        end

        # Sprint: sync if sprint date has passed and we don't have sprint results
        if weekend_race.sprint? && weekend_race.sprint_date && weekend_race.sprint_date <= today && weekend_race.sprint_results.empty?
            puts "Syncing sprint results for R#{weekend_race.round}..."
            UpdateSprintResult.new(race: weekend_race).update_all
            sleep 1
        end
    end

    def update_race_results(season)
        races_to_update = season.races
                                      .where(self.class.race_likely_finished_condition)
                                      .left_joins(:race_results)
                                      .where(race_results: { id: nil })
                                      .order(round: :asc)

        races_to_update.each do |race|
            # Confirm the race is actually finished via OpenF1 before syncing
            unless self.class.race_confirmed_finished?(race)
                puts "Skipping R#{race.round} — race not confirmed finished by OpenF1"
                next
            end

            puts "Updating results for Round #{race.round} (#{race.date})..."
            UpdateRaceResult.new(race: race).update_all
            sleep 1 # Be polite to the API
        end
    end

    def self.session_data_stale?(season)
        today = Date.current
        weekend_race = season.races
                             .where("date - 2 <= ? AND date >= ?", today, today)
                             .first
        return false unless weekend_race

        # Qualifying should exist if quali date has passed
        if weekend_race.quali_date && weekend_race.quali_date <= today && weekend_race.qualifying_results.empty?
            return true
        end

        # Sprint results should exist if sprint date has passed
        if weekend_race.sprint? && weekend_race.sprint_date && weekend_race.sprint_date <= today && weekend_race.sprint_results.empty?
            return true
        end

        false
    end

    # Initial filter: starts_at + 2h buffer must have passed (or date < today for old races without starts_at)
    def self.race_likely_finished_condition
        ["(races.starts_at IS NOT NULL AND races.starts_at + INTERVAL '2 hours' <= ?) OR (races.starts_at IS NULL AND races.date < ?)",
         Time.current, Date.current]
    end

    # Confirm with OpenF1 that the race session has ended (date_end has passed)
    def self.race_confirmed_finished?(race)
        # Old races (> 1 day ago) don't need confirmation
        return true if race.date < Date.current

        url = "#{OPENF1_SESSIONS}?year=#{race.year}&session_type=Race&circuit_short_name=#{URI.encode_www_form_component(race.circuit.location)}"
        data = JSON.parse(URI.open(url, read_timeout: 10).read)

        # Find the main race session (not sprint)
        race_session = data.select { |s| s["session_name"] == "Race" }.last
        return false unless race_session

        date_end = Time.parse(race_session["date_end"])
        finished = Time.current > date_end
        puts "OpenF1 check R#{race.round}: date_end=#{date_end}, now=#{Time.current}, finished=#{finished}"
        finished
    rescue OpenURI::HTTPError, Timeout::Error, JSON::ParserError, TypeError => e
        puts "OpenF1 check failed for R#{race.round}: #{e.message} — skipping sync"
        false # If we can't confirm, don't sync
    end

    def self.recently_synced?
        last_run = Rails.cache.read("season_sync:last_run")
        last_run.present?
    end
end
