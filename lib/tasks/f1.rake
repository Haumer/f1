namespace :f1 do
  desc "Sync current season schedule and race results from Jolpica API"
  task sync: :environment do
    year = ENV.fetch("YEAR", Date.current.year)
    puts "Syncing F1 season #{year}..."
    season = SeasonSync.new(year: year).sync
    if season
      puts "Done. #{season.races.count} races, #{season.races.joins(:race_results).distinct.count} with results."
    else
      puts "Failed to sync season #{year}."
    end
  end

  desc "Sync a range of seasons (e.g., YEARS=2020-2025)"
  task sync_range: :environment do
    range = ENV.fetch("YEARS", "#{Date.current.year}")
    start_year, end_year = range.split("-").map(&:to_i)
    end_year ||= start_year

    (start_year..end_year).each do |year|
      puts "\n=== Season #{year} ==="
      SeasonSync.new(year: year).sync
    end
    puts "\nDone."
  end

  desc "Run Elo V2 full historical simulation"
  task elo_v2_simulate: :environment do
    puts "Running Elo V2 simulation (K=#{EloRatingV2::BASE_K}, regression=#{EloRatingV2::REGRESSION_FACTOR}, start=#{EloRatingV2::STARTING_ELO})..."
    result = EloRatingV2.simulate_all!
    puts "Done. #{result[:drivers_updated]} drivers, #{result[:race_results_updated]} race results updated."

    # Show top 10 peaks
    puts "\nTop 10 All-Time Peak Elo V2:"
    Driver.where.not(peak_elo_v2: nil).order(peak_elo_v2: :desc).limit(10).each_with_index do |d, i|
      puts "  ##{i+1} #{d.fullname.ljust(25)} Peak: #{d.peak_elo_v2.round}  Current: #{d.elo_v2.round}"
    end
  end

  desc "Switch Elo display version (VERSION=v1 or VERSION=v2)"
  task elo_switch: :environment do
    version = ENV.fetch("VERSION", "v1")
    unless %w[v1 v2].include?(version)
      puts "Invalid version. Use VERSION=v1 or VERSION=v2"
      exit 1
    end
    Setting.set("elo_version", version)
    puts "Elo display switched to #{version}"
  end

  desc "Enqueue post-race sync job (for Heroku Scheduler)"
  task post_race_sync: :environment do
    PostRaceSyncJob.perform_later
    puts "PostRaceSyncJob enqueued."
  end

  desc "Fetch driver headshots from OpenF1 API"
  task headshots: :environment do
    puts "Fetching headshots from OpenF1..."
    count = FetchDriverHeadshots.fetch_all
    puts "Done. Updated #{count} driver headshots."
  end

  desc "Compute and store driver badges/achievements"
  task badges: :environment do
    puts "Computing driver badges..."
    count = DriverBadges.compute_all_drivers!
    puts "Done. #{count} badges computed for #{DriverBadge.select(:driver_id).distinct.count} drivers."
  end

  desc "Settle stock market for a race (pays dividends, charges borrow fees, snapshots)"
  task :settle_stock_market, [:race_id] => :environment do |_t, args|
    unless Setting.fantasy_stock_market?
      puts "Fantasy stock market is disabled. Enable it in Settings first."
      next
    end

    race = Race.find(args.fetch(:race_id))
    puts "Settling stock market for #{race.name}..."
    Fantasy::Stock::SettleRace.new(race: race).call

    settled = FantasyStockSnapshot.where(race: race).count
    puts "Done. #{settled} portfolios settled."
  end
end
