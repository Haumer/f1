class PostRaceSyncJob < ApplicationJob
  include Alertable

  queue_as :default

  def perform(year: Date.current.year)
    season = SeasonSync.new(year: year).sync
    unless season
      # If sync returned nil and there's a pending race in the post-race window,
      # start fast polling to catch it as soon as it's confirmed finished
      maybe_start_polling
      return
    end

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

    # Compute Elo for latest race (must happen before stock settlement/snapshots)
    latest_race = season.latest_race
    if latest_race&.race_results&.exists?
      EloRatingV2.process_race(latest_race)
      ConstructorEloV2.process_race(latest_race)
      Rails.logger.info "[PostRaceSyncJob] Elo computed for race #{latest_race.id}"

      # Replay cash from all transactions to keep wallets in sync
      Fantasy::ReplayTransactions.new(season: season).call
      Rails.logger.info "[PostRaceSyncJob] Fantasy cash replayed for race #{latest_race.id}"
    end
    if latest_race
      # Settle stock market first (dividends, borrow fees, margin calls)
      # so that cash is updated before snapshotting
      if Setting.fantasy_stock_market?
        Fantasy::Stock::SettleRace.new(race: latest_race).call
        Rails.logger.info "[PostRaceSyncJob] Stock market settled for race #{latest_race.id}"

        FantasyStockPortfolio.where(season: season).find_each do |portfolio|
          Fantasy::Stock::CheckAchievements.new(portfolio: portfolio, race: latest_race).call
        end
        Rails.logger.info "[PostRaceSyncJob] Stock achievements checked"
      end

      # Snapshot after settlement so cash reflects dividends/fees
      Fantasy::SnapshotPortfolios.new(race: latest_race).call
      Rails.logger.info "[PostRaceSyncJob] Fantasy snapshots created for race #{latest_race.id}"

      FantasyPortfolio.where(season: season).find_each do |portfolio|
        Fantasy::CheckAchievements.new(portfolio: portfolio, race: latest_race).call
      end
      Rails.logger.info "[PostRaceSyncJob] Fantasy achievements checked"
    end
  end

  private

  def maybe_start_polling
    season = Season.find_by(year: Date.current.year.to_s)
    return unless season

    race = season.next_race
    return unless race&.starts_at
    return unless Time.current >= race.starts_at + 2.hours
    return if race.race_results.exists?

    # Race should be done but wasn't synced — start fast polling
    Rails.logger.info "[PostRaceSyncJob] Starting fast poll for R#{race.round}"
    RaceFinishPollJob.perform_later
  end
end
