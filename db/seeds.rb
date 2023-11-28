require 'csv'
Driver.destroy_all
Circuit.destroy_all
Race.destroy_all
Status.destroy_all
Constructor.destroy_all
RaceResult.destroy_all

puts 'creating Drivers'
CSV.foreach("db/archive/drivers.csv", headers: :first_row) do |csv|
    attributes = { 
        kaggle_id: csv['driverId'].to_i,
        driver_ref: csv['driverRef'],
        surname: csv['surname'],
        forename: csv['forename'],
        code: csv['code'],
        number: csv['number'],
        dob: csv['dob'],
        nationality: csv['nationality'],
        url: csv['url'],
        elo: 1000
    }
    Driver.create(attributes)
end

puts 'creating Circuits'
CSV.foreach("db/archive/circuits.csv", headers: :first_row) do |csv|
    attributes = { 
        kaggle_id: csv['circuitId'].to_i,
        circuit_ref: csv['circuitRef'],
        name: csv['name'],
        location: csv['location'],
        country: csv['country'],
        lat: csv['lat'],
        lng: csv['lng'],
        alt: csv['alt'],
        url: csv['url'],
    }
    Circuit.create(attributes)
end

puts 'creating Races'
CSV.foreach("db/archive/races.csv", headers: :first_row) do |csv|
    season = Season.find_or_create_by(year: csv['year'])
    attributes = {
        season: season, 
        kaggle_id: csv['raceId'],
        year: csv['year'],
        round: csv['round'],
        date: Date.parse(csv['date']),
        url: csv['url'],
        circuit: Circuit.find_by(kaggle_id: csv['circuitId'])
    }
    Race.create(attributes)
end

puts 'creating Statuses'
CSV.foreach("db/archive/status.csv", headers: :first_row) do |csv|
    attributes = { 
        kaggle_id: csv['statusId'],
        status_type: csv['status'],
    }
    Status.create(attributes)
end

puts 'creating Constructors'
CSV.foreach("db/archive/constructors.csv", headers: :first_row) do |csv|
    attributes = { 
        kaggle_id: csv['constructorId'],
        constructor_ref: csv['constructorRef'],
        name: csv['name'],
        nationality: csv['nationality'],
        url: csv['url'],
    }
    Constructor.create(attributes)
end

puts 'creating RaceResults'
race_id = nil
CSV.foreach("db/archive/results.csv", headers: :first_row) do |csv|
    if csv['raceId'] != race_id || race_id.nil? 
        race_id = csv['raceId'] 
        puts "Race: #{race_id}"
    end
    attributes = { 
        kaggle_id: csv['resultId'],
        number: csv['number'],
        position: csv['position'].to_i != 0 ? csv['position'].to_i : nil,
        position_order: csv['positionOrder'].to_i != 0 ? csv['positionOrder'].to_i : nil,
        grid: csv['grid'].to_i,
        points: csv['points'].to_i,
        laps: csv['laps'],
        time: csv['time'],
        milliseconds: csv['milliseconds'] != '\\N' ? csv['milliseconds'] : nil,
        fastest_lap: csv['fastestLap'],
        fastest_lap_time: csv['fastestLapTime'],
        fastest_lap_speed: csv['fastestLapSpeed'],
        race: Race.find_by(kaggle_id: csv['raceId']),
        driver: Driver.find_by(kaggle_id: csv['driverId']),
        constructor: Constructor.find_by(kaggle_id: csv['constructorId']),
        status: Status.find_by(kaggle_id: csv['statusId']),
    }
    RaceResult.create(attributes)
end

puts 'creating DriversStandings'
CSV.foreach("db/archive/driver_standings.csv", headers: :first_row) do |csv|
    attributes = { 
        kaggle_id: csv['driverStandingsId'].to_i,
        driver: Driver.find_by(kaggle_id: csv['driverId'].to_i),
        race: Race.find_by(kaggle_id: csv['raceId'].to_i),
        points: csv['points'].to_f,
        position: csv['position'].to_i,
        wins: csv['wins'],
    }
    p DriverStanding.create(attributes)
end

puts 'creating ConstructorStandings'
CSV.foreach("db/archive/constructor_standings.csv", headers: :first_row) do |csv|
    attributes = { 
        kaggle_id: csv['constructorStandingsId'].to_i,
        constructor: Constructor.find_by(kaggle_id: csv['constructorId'].to_i),
        race: Race.find_by(kaggle_id: csv['raceId'].to_i),
        points: csv['points'].to_f,
        position: csv['position'].to_i,
        wins: csv['wins'],
    }
    p ConstructorStanding.create(attributes)
end

season_videos = [
    {
        season: Season.find_by(year: 2017),
        video_media: "https://www.youtube.com/watch?v=MuboH1zT_P8&t=292s&ab_channel=CYMotorsport"
    },
    {
        season: Season.find_by(year: 2010),
        video_media: "https://www.youtube.com/watch?v=8X9iAgzmeI4&ab_channel=CYMotorsport",
    }
    {
        season: Season.find_by(year: 2012),
        video_media: "https://www.youtube.com/watch?v=h0m30qw4g6o&ab_channel=CYMotorsport",
    }
]