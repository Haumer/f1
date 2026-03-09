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

  desc "Run Elo full historical simulation"
  task elo_simulate: :environment do
    puts "Running Elo simulation (K=#{EloRatingV2::BASE_K}, ref_races=#{EloRatingV2::REFERENCE_RACES.to_i}, start=#{EloRatingV2::STARTING_ELO})..."
    result = EloRatingV2.simulate_all!
    puts "Done. #{result[:drivers_updated]} drivers, #{result[:race_results_updated]} race results updated."

    puts "\nTop 10 All-Time Peak Elo:"
    Driver.where.not(peak_elo_v2: nil).order(peak_elo_v2: :desc).limit(10).each_with_index do |d, i|
      puts "  ##{i+1} #{d.fullname.ljust(25)} Peak: #{d.peak_elo_v2.round}  Current: #{d.elo_v2.round}"
    end
  end

  # Keep old task name as alias
  task elo_v2_simulate: :elo_simulate

  desc "Run Constructor Elo full historical simulation"
  task constructor_elo_simulate: :environment do
    puts "Running Constructor Elo simulation (K=#{ConstructorEloV2::BASE_K}, ref_races=#{ConstructorEloV2::REFERENCE_RACES.to_i}, start=#{ConstructorEloV2::STARTING_ELO})..."
    result = ConstructorEloV2.simulate_all!
    puts "Done. #{result[:constructors_updated]} constructors, #{result[:race_results_updated]} race results updated."

    puts "\nTop 10 All-Time Peak Constructor Elo:"
    Constructor.where.not(peak_elo_v2: nil).order(peak_elo_v2: :desc).limit(10).each_with_index do |c, i|
      puts "  ##{i+1} #{c.name.ljust(25)} Peak: #{c.peak_elo_v2.round}  Current: #{c.elo_v2.round}"
    end
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
      { driver_ref: "arvid_lindblad", constructor_ref: "rb" },
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

  desc "Fetch qualifying results for a season (YEAR=2026, or all with START/END)"
  task qualifying: :environment do
    start_year = ENV.fetch("START", ENV.fetch("YEAR", Date.current.year.to_s)).to_i
    end_year = ENV.fetch("END", start_year.to_s).to_i

    total = 0
    (start_year..end_year).each do |year|
      season = Season.find_by(year: year.to_s)
      unless season
        puts "Season #{year} not found, skipping."
        next
      end

      races = season.races.order(:round)
      puts "=== #{year}: #{races.count} races ==="
      races.each do |race|
        count = UpdateQualifyingResult.new(race: race).call
        if count
          puts "  R#{race.round} #{race.circuit&.name}: #{count} qualifying results"
          total += count
        else
          puts "  R#{race.round} #{race.circuit&.name}: no data"
        end
        sleep 0.5 # rate limit
      end
    end
    puts "\nDone. #{total} qualifying results stored."
  end

  desc "Auto-fetch qualifying results for races where qualifying has finished"
  task qualifying_sync: :environment do
    season = Season.sorted_by_year.first
    now = Time.current
    expected = season.season_drivers.count

    season.races.each do |race|
      next if race.qualifying_results.count >= expected # already fetched
      next unless race.quali_starts_at
      next unless race.quali_starts_at + 2.hours < now # quali should be done
      next if race.quali_starts_at + 24.hours < now # too old, skip

      puts "Enqueuing qualifying sync for R#{race.round} #{race.circuit&.name}"
      QualifyingSyncJob.perform_later(race_id: race.id)
    end
  end

  desc "Replay all fantasy transactions to recalculate cash balances (DRY_RUN=1 for preview)"
  task replay_transactions: :environment do
    dry_run = ENV.fetch("DRY_RUN", "0") == "1"
    season = Season.sorted_by_year.first
    puts dry_run ? "DRY RUN — no changes will be saved" : "LIVE — recalculating cash balances"
    puts "Season: #{season.year}"

    results = Fantasy::ReplayTransactions.new(season: season, dry_run: dry_run).call
    results.each do |r|
      status = r[:diff].abs < 0.01 ? "OK" : "CHANGED"
      puts "  #{r[:user].ljust(15)} #{r[:old_cash]} -> #{r[:new_cash]} (#{r[:diff] >= 0 ? '+' : ''}#{r[:diff]}) [#{status}]"
    end
    puts "Done."
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
