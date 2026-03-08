require 'csv'

namespace :f1 do
  desc "Backfill all historical data from CSV archives and calculate ELO ratings"
  task backfill: :environment do
    archive = Rails.root.join("db", "archive")

    puts "=== Loading reference data ==="
    load_statuses(archive)
    load_circuits(archive)
    load_constructors(archive)
    load_drivers(archive)

    puts "\n=== Loading seasons & races ==="
    load_races(archive)

    puts "\n=== Loading race results ==="
    load_results(archive)

    puts "\n=== Loading driver standings ==="
    load_driver_standings(archive)

    puts "\n=== Loading constructor standings ==="
    load_constructor_standings(archive)

    puts "\n=== Creating season_drivers ==="
    create_season_drivers

    puts "\n=== Calculating ELO ratings (chronological) ==="
    calculate_elo

    puts "\n=== Updating driver standing stats ==="
    update_driver_standing_stats

    puts "\n=== Syncing 2024 from API ==="
    SeasonSync.new(year: 2024).sync

    puts "\n=== Done ==="
    puts "Seasons: #{Season.count}"
    puts "Races: #{Race.count}"
    puts "Drivers: #{Driver.count}"
    puts "RaceResults: #{RaceResult.count}"
    puts "DriverStandings: #{DriverStanding.count}"
  end
end

def null_safe(val)
  val == "\\N" || val.blank? ? nil : val
end

def load_statuses(archive)
  print "Statuses... "
  count = 0
  CSV.foreach(archive.join("status.csv"), headers: true) do |row|
    Status.find_or_create_by(kaggle_id: row['statusId'].to_i) do |s|
      s.status_type = row['status']
      count += 1
    end
  end
  puts "#{count} new (#{Status.count} total)"
end

def load_circuits(archive)
  print "Circuits... "
  count = 0
  CSV.foreach(archive.join("circuits.csv"), headers: true) do |row|
    Circuit.find_or_create_by(kaggle_id: row['circuitId'].to_i) do |c|
      c.circuit_ref = row['circuitRef']
      c.name = row['name']
      c.location = row['location']
      c.country = row['country']
      c.lat = null_safe(row['lat'])&.to_f
      c.lng = null_safe(row['lng'])&.to_f
      c.alt = null_safe(row['alt'])&.to_i
      c.url = row['url']
      count += 1
    end
  end
  puts "#{count} new (#{Circuit.count} total)"
end

def load_constructors(archive)
  print "Constructors... "
  count = 0
  CSV.foreach(archive.join("constructors.csv"), headers: true) do |row|
    Constructor.find_or_create_by(kaggle_id: row['constructorId'].to_i) do |c|
      c.constructor_ref = row['constructorRef']
      c.name = row['name']
      c.nationality = row['nationality']
      c.url = row['url']
      count += 1
    end
  end
  puts "#{count} new (#{Constructor.count} total)"
end

def load_drivers(archive)
  print "Drivers... "
  count = 0
  CSV.foreach(archive.join("drivers.csv"), headers: true) do |row|
    Driver.find_or_create_by(kaggle_id: row['driverId'].to_i) do |d|
      d.driver_ref = row['driverRef']
      d.number = null_safe(row['number'])&.to_i
      d.code = null_safe(row['code'])
      d.forename = row['forename']
      d.surname = row['surname']
      d.dob = null_safe(row['dob'])
      d.nationality = row['nationality']
      d.url = row['url']
      d.elo = 1000
      d.peak_elo = 1000
      count += 1
    end
  end
  puts "#{count} new (#{Driver.count} total)"
end

def load_races(archive)
  count = 0
  last_rounds = {}

  # First pass: find last round per season
  CSV.foreach(archive.join("races.csv"), headers: true) do |row|
    year = row['year']
    round = row['round'].to_i
    last_rounds[year] = [last_rounds[year].to_i, round].max
  end

  CSV.foreach(archive.join("races.csv"), headers: true) do |row|
    season = Season.find_or_create_by(year: row['year'])
    circuit = Circuit.find_by(kaggle_id: row['circuitId'].to_i)
    next unless circuit

    round = row['round'].to_i
    Race.find_or_create_by(kaggle_id: row['raceId'].to_i) do |r|
      r.season = season
      r.year = row['year'].to_i
      r.round = round
      r.date = Date.parse(row['date'])
      r.url = row['url']
      r.circuit = circuit
      r.season_end = (round == last_rounds[row['year']])
      count += 1
    end
  end
  puts "#{count} new races (#{Race.count} total across #{Season.count} seasons)"
end

def load_results(archive)
  count = 0
  batch = []
  total = `wc -l < #{archive.join("results.csv")}`.strip.to_i - 1

  CSV.foreach(archive.join("results.csv"), headers: true) do |row|
    race = Race.find_by(kaggle_id: row['raceId'].to_i)
    driver = Driver.find_by(kaggle_id: row['driverId'].to_i)
    constructor = Constructor.find_by(kaggle_id: row['constructorId'].to_i)
    status = Status.find_by(kaggle_id: row['statusId'].to_i)
    next unless race && driver && constructor && status

    rr = RaceResult.find_or_initialize_by(race: race, driver: driver)
    if rr.new_record?
      rr.kaggle_id = row['resultId'].to_i
      rr.constructor = constructor
      rr.status = status
      rr.number = null_safe(row['number'])&.to_i
      rr.grid = row['grid'].to_i
      rr.position = null_safe(row['position'])&.to_i
      rr.position_order = null_safe(row['positionOrder'])&.to_i
      rr.points = row['points'].to_i
      rr.laps = row['laps']
      rr.time = null_safe(row['time'])
      rr.milliseconds = null_safe(row['milliseconds'])
      rr.fastest_lap = null_safe(row['fastestLap'])&.to_i
      rr.fastest_lap_time = null_safe(row['fastestLapTime'])
      rr.fastest_lap_speed = null_safe(row['fastestLapSpeed'])&.to_f
      rr.save!
      count += 1
    end

    print "\r  Results: #{count}/#{total}" if count % 500 == 0
  end
  puts "\r  Results: #{count} new (#{RaceResult.count} total)"
end

def load_driver_standings(archive)
  count = 0
  total = `wc -l < #{archive.join("driver_standings.csv")}`.strip.to_i - 1

  CSV.foreach(archive.join("driver_standings.csv"), headers: true) do |row|
    race = Race.find_by(kaggle_id: row['raceId'].to_i)
    driver = Driver.find_by(kaggle_id: row['driverId'].to_i)
    next unless race && driver

    DriverStanding.find_or_create_by(kaggle_id: row['driverStandingsId'].to_i) do |ds|
      ds.race = race
      ds.driver = driver
      ds.points = row['points'].to_f
      ds.position = row['position'].to_i
      ds.wins = row['wins'].to_i
      count += 1
    end

    print "\r  Standings: #{count}/#{total}" if count % 500 == 0
  end
  puts "\r  Standings: #{count} new (#{DriverStanding.count} total)"
end

def load_constructor_standings(archive)
  count = 0

  CSV.foreach(archive.join("constructor_standings.csv"), headers: true) do |row|
    race = Race.find_by(kaggle_id: row['raceId'].to_i)
    constructor = Constructor.find_by(kaggle_id: row['constructorId'].to_i)
    next unless race && constructor

    ConstructorStanding.find_or_create_by(kaggle_id: row['constructorStandingsId'].to_i) do |cs|
      cs.race = race
      cs.constructor = constructor
      cs.points = row['points'].to_f
      cs.position = row['position'].to_i
      cs.wins = row['wins'].to_i
      count += 1
    end

    print "\r  Constructor standings: #{count}" if count % 500 == 0
  end
  puts "\r  Constructor standings: #{count} new (#{ConstructorStanding.count} total)"
end

def create_season_drivers
  count = 0
  RaceResult.includes(:race, :driver, :constructor).find_each do |rr|
    next unless rr.race&.season && rr.constructor

    SeasonDriver.find_or_create_by(
      season: rr.race.season,
      driver: rr.driver,
      constructor: rr.constructor
    ) do |sd|
      sd.active = true
      count += 1
    end

    print "\r  SeasonDrivers: #{count}" if count % 200 == 0
  end
  puts "\r  SeasonDrivers: #{count} new (#{SeasonDriver.count} total)"

  # Set driver first/last race dates
  Driver.find_each do |driver|
    dates = driver.race_results.joins(:race).pluck('races.date')
    next if dates.empty?
    driver.update_columns(first_race_date: dates.min, last_race_date: dates.max)
  end
  puts "  Updated driver race dates"
end

def calculate_elo
  puts "  Running EloRatingV2.simulate_all!..."
  result = EloRatingV2.simulate_all!
  puts "  ELO: #{result[:drivers_updated]} drivers, #{result[:race_results_updated]} race results updated."
end

def update_driver_standing_stats
  seasons = Season.all.order(:year)
  total = seasons.count

  seasons.each_with_index do |season, i|
    season.drivers.distinct.each do |driver|
      UpdateDriverStanding.new(driver: driver, season: season).update
    end
    print "\r  Stats: #{i + 1}/#{total} seasons" if (i + 1) % 5 == 0
  end
  puts "\r  Stats: #{total}/#{total} seasons complete"

  # Mark season-end standings
  Season.find_each do |season|
    last_race = season.races.order(round: :desc).first
    next unless last_race
    DriverStanding.where(race: last_race).update_all(season_end: true)
  end
  puts "  Marked season-end standings"
end
