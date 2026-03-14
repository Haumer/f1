require 'json'
require 'open-uri'

class SeasonSync
    STATUSES_ENDPOINT = "https://api.jolpi.ca/ergast/f1/status.json?limit=200"

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

        # Race results missing for past races
        races_needing_update = season.races.where("date <= ?", Date.current)
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

            # Update standings immediately so sprint points are reflected
            puts "Updating standings with sprint points for R#{weekend_race.round}..."
            UpdateRaceResult.new(race: weekend_race).send(:create_standings_from_results)
        end
    end

    def update_race_results(season)
        races_to_update = season.races.where("date <= ?", Date.current)
                                      .left_joins(:race_results)
                                      .where(race_results: { id: nil })
                                      .order(round: :asc)

        races_to_update.each do |race|
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

    def self.recently_synced?
        last_run = Rails.cache.read("season_sync:last_run")
        last_run.present?
    end
end
