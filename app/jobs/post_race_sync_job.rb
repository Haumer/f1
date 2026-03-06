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

    # Mark season_end standings on last race of each completed season
    last_race = season.races.order(round: :desc).first
    if last_race&.race_results&.exists?
      DriverStanding.where(race: last_race).update_all(season_end: true)
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

      # Settle stock market (dividends, borrow fees, margin calls, snapshots)
      if Setting.fantasy_stock_market?
        Fantasy::Stock::SettleRace.new(race: latest_race).call
        Rails.logger.info "[PostRaceSyncJob] Stock market settled for race #{latest_race.id}"

        # Check stock achievements
        FantasyStockPortfolio.where(season: season).find_each do |portfolio|
          Fantasy::Stock::CheckAchievements.new(portfolio: portfolio, race: latest_race).call
        end
        Rails.logger.info "[PostRaceSyncJob] Stock achievements checked"
      end
    end
  end
end
