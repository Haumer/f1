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

  desc "Seed 2026 pre-season driver lineup"
  task seed_2026_lineup: :environment do
    season = Season.find_by(year: "2026")
    unless season
      puts "Season 2026 not found. Run f1:sync YEAR=2026 first."
      next
    end

    lineup = [
      { driver_ref: "antonelli", constructor_ref: "mercedes" },
      { driver_ref: "bearman", constructor_ref: "haas" },
      { driver_ref: "lawson", constructor_ref: "rb" },
      { driver_ref: "bortoleto", constructor_ref: "audi" },
      { driver_ref: "hadjar", constructor_ref: "red_bull" },
      { driver_ref: "colapinto", constructor_ref: "alpine" },
      { driver_ref: "hamilton", constructor_ref: "ferrari" },
      { driver_ref: "alonso", constructor_ref: "aston_martin" },
      { driver_ref: "gasly", constructor_ref: "alpine" },
      { driver_ref: "hulkenberg", constructor_ref: "audi" },
      { driver_ref: "perez", constructor_ref: "cadillac" },
      { driver_ref: "bottas", constructor_ref: "cadillac" },
      { driver_ref: "max_verstappen", constructor_ref: "red_bull" },
      { driver_ref: "sainz", constructor_ref: "williams" },
      { driver_ref: "ocon", constructor_ref: "haas" },
      { driver_ref: "stroll", constructor_ref: "aston_martin" },
      { driver_ref: "leclerc", constructor_ref: "ferrari" },
      { driver_ref: "norris", constructor_ref: "mclaren" },
      { driver_ref: "russell", constructor_ref: "mercedes" },
      { driver_ref: "albon", constructor_ref: "williams" },
      { driver_ref: "piastri", constructor_ref: "mclaren" },
      { driver_ref: "lindblad", constructor_ref: "rb" },
    ]

    created = 0
    lineup.each do |entry|
      driver = Driver.find_by(driver_ref: entry[:driver_ref])
      constructor = Constructor.find_by(constructor_ref: entry[:constructor_ref])

      unless driver
        puts "  SKIP: driver '#{entry[:driver_ref]}' not found"
        next
      end
      unless constructor
        puts "  SKIP: constructor '#{entry[:constructor_ref]}' not found"
        next
      end

      sd = SeasonDriver.find_or_create_by(season: season, driver: driver, constructor: constructor, standin: false)
      if sd.previously_new_record?
        created += 1
        puts "  Created: #{driver.fullname} -> #{constructor.name}"
      end
    end

    # Mark these drivers as active
    driver_ids = lineup.filter_map { |e| Driver.find_by(driver_ref: e[:driver_ref])&.id }
    Driver.where(id: driver_ids).update_all(active: true)

    # Mark all 2026 constructors as active
    constructor_refs = lineup.map { |e| e[:constructor_ref] }.uniq
    Constructor.where(constructor_ref: constructor_refs).update_all(active: true)

    puts "Done. #{created} new SeasonDriver records created. #{driver_ids.size} drivers marked active."
  end

  desc "Full data sync: sync all seasons, Elo, careers, standings, logos, badges"
  task full_sync: :environment do
    start_year = ENV.fetch("START", "1950").to_i
    end_year = ENV.fetch("END", Date.current.year.to_s).to_i
    FullDataSyncJob.perform_now(start_year: start_year, end_year: end_year)
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
