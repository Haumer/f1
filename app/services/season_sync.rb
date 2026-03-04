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

        update_race_results(season)
        season.reload
    end

    # Check if the current season data is stale (new race results available)
    def self.stale?
        season = Season.find_by(year: Date.current.year.to_s)
        return true unless season

        races_needing_update = season.races.where("date <= ?", Date.current)
                                          .left_joins(:race_results)
                                          .where(race_results: { id: nil })
        races_needing_update.exists?
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

    def self.recently_synced?
        last_run = Rails.cache.read("season_sync:last_run")
        last_run.present?
    end
end
