class PostRaceSyncJob < ApplicationJob
  include Alertable

  queue_as :default

  def perform(year: Date.current.year)
    season = SeasonSync.new(year: year).sync
    return unless season

    # Update career stats for drivers who raced this season
    driver_ids = season.race_results.select(:driver_id).distinct
    Driver.where(id: driver_ids).find_each do |driver|
      UpdateDriverCareer.new(driver: driver).update
    end

    DriverBadges.compute_all_drivers!
    UpdateActiveDrivers.update_season

    # Snapshot fantasy portfolios
    latest_race = season.latest_race
    if latest_race
      Fantasy::SnapshotPortfolios.new(race: latest_race).call
      Rails.logger.info "[PostRaceSyncJob] Fantasy snapshots created for race #{latest_race.id}"

      # Check fantasy achievements
      FantasyPortfolio.where(season: season).find_each do |portfolio|
        Fantasy::CheckAchievements.new(portfolio: portfolio, race: latest_race).call
      end
      Rails.logger.info "[PostRaceSyncJob] Fantasy achievements checked"
    end
  end
end
