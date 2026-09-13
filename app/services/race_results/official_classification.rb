require 'net/http'
require 'nokogiri'

module RaceResults
  # Explicit repair input, not an automatic scraper fallback. The operator
  # supplies the official event URL; date, circuit, field and grid must agree.
  # Fetching/parsing is read-only and never creates drivers, teams or statuses.
  class OfficialClassification
    TEAMS = {
      'Mercedes' => 'mercedes', 'Red Bull Racing' => 'red_bull', 'McLaren' => 'mclaren',
      'Ferrari' => 'ferrari', 'Alpine' => 'alpine', 'Racing Bulls' => 'rb',
      'Audi' => 'audi', 'Haas F1 Team' => 'haas', 'Williams' => 'williams',
      'Aston Martin' => 'aston_martin', 'Cadillac' => 'cadillac'
    }.freeze

    def initialize(race:, url:)
      @race, @url = race, url
    end

    def call
      uri = URI(@url)
      unless uri.scheme == 'https' && uri.host == 'www.formula1.com' &&
          uri.path.match?(%r{\A/en/results/#{@race.year}/races/\d+/[a-z-]+/race-result\z}) && !uri.query && !uri.fragment
        raise ImportGuard::Rejected, 'Use the official Formula 1 race-result URL'
      end
      results = table(fetch(uri), ['Pos.', 'No.', 'Driver', 'Team', 'Laps', 'Time / Retired', 'Pts.'])
      grid_uri = uri.dup
      grid_uri.path = uri.path.sub('/race-result', '/starting-grid')
      grid_rows = table(fetch(grid_uri), ['Pos.', 'No.', 'Driver', 'Team', 'Time'])
      grid = grid_rows.to_h { |cells| [code(cells[2]), Integer(cells[0].text.strip)] }
      raise ImportGuard::Rejected, 'Duplicate driver in starting grid' unless grid_rows.size == grid.size
      field = @race.race_results.includes(:driver).map(&:driver)
      drivers = field.index_by(&:code)
      surnames = field.group_by { |driver| I18n.transliterate(driver.surname).downcase }
      teams = Constructor.where(constructor_ref: TEAMS.values).index_by(&:constructor_ref)
      statuses = Status.all.index_by(&:status_type)
      seen = []

      rows = results.each_with_index.map do |cells, index|
        driver_code = code(cells[2])
        surname = cells[2].css('span').find { |span| span['class'].to_s.split.include?('max-md:hidden') }&.text.to_s.strip
        namesakes = surnames[I18n.transliterate(surname).downcase] || []
        driver = drivers[driver_code] || (namesakes.one? ? namesakes.first : nil)
        raise ImportGuard::Rejected, "Unknown event driver #{driver_code}" unless driver && namesakes.include?(driver)
        raise ImportGuard::Rejected, 'Duplicate driver in official table' if seen.include?(driver_code)
        seen << driver_code
        position = cells[0].text.strip
        time = cells[5].text.strip
        classified = position.match?(/\A\d+\z/)
        raise ImportGuard::Rejected, 'Official results are not in classification order' if classified && Integer(position) != index + 1
        status_name = if !classified
          raise ImportGuard::Rejected, "Unsupported result #{position}/#{time}" unless position == 'NC' && time == 'DNF'
          'Retired'
        elsif time.match?(/\A\+\d+ laps?\z/i)
          "+#{time[/\d+/]} #{time[/\d+/] == '1' ? 'Lap' : 'Laps'}"
        else
          'Finished'
        end
        { driver_id: driver.id, constructor_id: teams.fetch(TEAMS.fetch(cells[3].text.strip)).id,
          status_id: statuses.fetch(status_name).id, position: classified ? Integer(position) : index + 1,
          position_order: index + 1, points: Float(cells[6].text), laps: Integer(cells[4].text),
          time: time, grid: grid.fetch(driver_code), number: Integer(cells[1].text),
          milliseconds: nil, fastest_lap: nil, fastest_lap_time: nil, fastest_lap_speed: nil }
      end
      unless rows.size == field.size && grid.size == rows.size && seen.sort == grid.keys.sort
        raise ImportGuard::Rejected, 'Official result, starting grid and stored field must be complete and identical'
      end
      ImportGuard.new(race: @race).validate_rows!(rows)
      rows
    rescue KeyError, ArgumentError => e
      raise ImportGuard::Rejected, "Incomplete or unsupported official classification: #{e.message}"
    end

    private

    def fetch(uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.get(uri.request_uri) }
      raise ImportGuard::Rejected, "Official source returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      Nokogiri::HTML(response.body.force_encoding('UTF-8'))
    end

    def table(document, headers)
      text = document.xpath('//text()[not(ancestor::script) and not(ancestor::style)]').map(&:text).join(' ').gsub(/\s+/, ' ')
      date = /\b0?#{@race.date.day} #{@race.date.strftime('%b %Y')}\b/
      unless text.match?(date) && text.include?(@race.circuit.name)
        raise ImportGuard::Rejected, 'Official page date or circuit does not match the target race'
      end
      candidate = document.css('table').find { |t| t.css('thead th').map { |c| c.text.strip } == headers }
      raise ImportGuard::Rejected, 'Official classification table is missing or changed' unless candidate
      candidate.css('tbody tr').map { |row| row.css('td') }
    end

    def code(cell)
      cell.css('span').find { |span| span['class'].to_s.split.include?('md:hidden') }&.text&.strip ||
        raise(ImportGuard::Rejected, 'Official driver code is missing')
    end
  end
end
