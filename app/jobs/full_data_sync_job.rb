class FullDataSyncJob < ApplicationJob
  include Alertable

  queue_as :default

  # Full data population: sync all seasons, compute Elo, backfill careers,
  # mark season_end standings, update logos/colors, compute badges.
  # Safe to re-run — idempotent.
  def perform(start_year: 1950, end_year: Date.current.year)
    log "Starting full data sync (#{start_year}-#{end_year})..."

    # 1. Sync all seasons from API
    (start_year..end_year).each do |year|
      log "Syncing season #{year}..."
      SeasonSync.new(year: year).sync
      sleep 0.5
    end

    # 2. Mark season_end on driver/constructor standings
    log "Marking season_end standings..."
    mark_season_end_standings

    # 3. Run Elo V2 simulation
    log "Running Elo V2 simulation..."
    result = EloRatingV2.simulate_all!
    log "Elo V2: #{result[:drivers_updated]} drivers, #{result[:race_results_updated]} results"

    # 4. Run Constructor Elo V2
    log "Running Constructor Elo V2..."
    ConstructorEloV2.simulate_all!

    # 5. Backfill career stats
    log "Backfilling career stats..."
    Driver.find_each do |driver|
      UpdateDriverCareer.new(driver: driver).update
    end

    # 6. Update driver colors from latest constructor
    log "Updating driver colors..."
    update_driver_colors

    # 7. Update constructor logos
    log "Updating constructor logos..."
    update_constructor_logos

    # 8. Update active drivers/constructors
    log "Updating active flags..."
    UpdateActiveDrivers.update_season

    # 9. Compute badges
    log "Computing badges..."
    DriverBadges.compute_all_drivers!

    # 10. Fetch headshots
    log "Fetching headshots..."
    FetchDriverHeadshots.fetch_all

    log "Full data sync complete."
  end

  private

  def mark_season_end_standings
    Season.find_each do |season|
      last_race = season.races.order(round: :desc).first
      next unless last_race
      next unless last_race.race_results.exists? # only if race has been run

      DriverStanding.where(race: last_race).update_all(season_end: true)
      ConstructorStanding.where(race: last_race).update_all(season_end: true) if defined?(ConstructorStanding)
    end
  end

  def update_driver_colors
    Driver.find_each do |driver|
      sd = driver.season_drivers.joins(:season).order("seasons.year DESC").includes(:constructor).first
      next unless sd&.constructor
      color = Constructor::COLORS[sd.constructor.constructor_ref.to_sym]
      next unless color
      driver.update_column(:color, color) unless driver.color == color
    end
  end

  def update_constructor_logos
    Constructor::LOGOS.each do |ref, url|
      Constructor.where(constructor_ref: ref).update_all(logo_url: url)
    end
  end

  def log(msg)
    Rails.logger.info "[FullDataSyncJob] #{msg}"
    puts msg if $stdout.tty?
  end
end
