require 'json'
require 'open-uri'

class UpdateSprintResult
  ENDPOINT = 'https://api.jolpi.ca/ergast/f1'

  def initialize(race:)
    @race = race
    @data = fetch_data
  end

  def update_all
    return unless has_results?

    puts "Syncing sprint results for #{@race.year}/#{@race.round}"
    sync_results
  end

  private

  def fetch_data
    url = "#{ENDPOINT}/#{@race.year}/#{@race.round}/sprint.json"
    JSON.parse(URI.open(url, read_timeout: 30).read)
  rescue OpenURI::HTTPError, Timeout::Error, JSON::ParserError => e
    puts "No sprint results for #{@race.year}/#{@race.round}: #{e.message}"
    nil
  end

  def has_results?
    return false unless @data
    races = @data.dig('MRData', 'RaceTable', 'Races')
    races&.first&.dig('SprintResults')&.any? || false
  end

  def sync_results
    races = @data.dig('MRData', 'RaceTable', 'Races')
    sprint_results = races.first['SprintResults']

    all_drivers = Driver.all.index_by(&:driver_ref)
    all_statuses = Status.all.index_by(&:status_type)

    sprint_results.each do |sr|
      driver = all_drivers[sr['Driver']['driverId']]
      next unless driver

      constructor = Constructor.find_or_create_by(constructor_ref: sr['Constructor']['constructorId']) do |c|
        c.name = sr['Constructor']['name']
      end

      status = all_statuses[sr['status']]
      unless status
        status = Status.create!(status_type: sr['status'])
        all_statuses[status.status_type] = status
      end

      # Use unscoped to bypass default_scope when finding/creating sprint results
      result = RaceResult.unscoped.find_or_initialize_by(
        driver: driver,
        race: @race,
        result_type: "sprint"
      )
      result.update!(
        constructor: constructor,
        status: status,
        position: sr['position'],
        position_order: sr['positionOrder'] || sr['position'],
        points: sr['points'],
        time: sr.dig('Time', 'time') || 0,
        laps: sr['laps'],
        milliseconds: sr.dig('Time', 'millis'),
        fastest_lap_time: sr.dig('FastestLap', 'Time', 'time'),
        fastest_lap_speed: sr.dig('FastestLap', 'AverageSpeed', 'speed'),
        fastest_lap: sr.dig('FastestLap', 'lap'),
        grid: sr['grid'],
        number: sr['number'],
      )
    end

    puts "Synced #{sprint_results.size} sprint results"
  end
end
