require "net/http"
require "json"
require "uri"

class WikipediaRaceResultFetcher
  API_BASE = "https://en.wikipedia.org/w/api.php"

  # Maps Wikipedia constructor display names / link targets to constructor_refs
  CONSTRUCTOR_MAP = {
    # 2024-2026 grid
    "Mercedes"                          => "mercedes",
    "Mercedes-Benz in Formula One"      => "mercedes",
    "Mercedes AMG High Performance Powertrains" => nil, # engine supplier, skip
    "Ferrari"                           => "ferrari",
    "Scuderia Ferrari"                  => "ferrari",
    "McLaren"                           => "mclaren",
    "Red Bull Racing"                   => "red_bull",
    "Oracle Red Bull Racing"            => "red_bull",
    "Aston Martin in Formula One"       => "aston_martin",
    "Aston Martin Aramco"               => "aston_martin",
    "Alpine F1 Team"                    => "alpine",
    "Alpine"                            => "alpine",
    "Williams Racing"                   => "williams",
    "Williams"                          => "williams",
    "Atlassian Williams"                => "williams",
    "Haas F1 Team"                      => "haas",
    "Haas"                              => "haas",
    "MoneyGram Haas F1 Team"            => "haas",
    "RB F1 Team"                        => "rb",
    "Racing Bulls"                      => "rb",
    "RB"                                => "rb",
    "Sauber"                            => "sauber",
    "Kick Sauber"                       => "sauber",
    "Stake F1 Team Kick Sauber"         => "sauber",
    "Audi"                              => "audi",
    "Audi in Formula One"               => "audi",
    "Cadillac"                          => "cadillac",
    "Cadillac F1 Team"                  => "cadillac",
    "Cadillac in Formula One"           => "cadillac",
    # Historical teams likely encountered
    "Renault"                           => "renault",
    "Renault in Formula One"            => "renault",
    "Toro Rosso"                        => "toro_rosso",
    "AlphaTauri"                        => "alphatauri",
    "Force India"                       => "force_india",
    "Racing Point"                      => "racing_point",
    "Alfa Romeo"                        => "alfa",
    "Alfa Romeo in Formula One"         => "alfa",
    "Lotus F1"                          => "lotus_f1",
    "Honda in Formula One"              => nil, # engine supplier
    "Red Bull Powertrains"              => nil, # engine supplier
    "Red Bull Ford"                     => nil, # engine supplier
  }.freeze

  # Maps Wikipedia status text to our Status.status_type
  STATUS_POSITION_MAP = {
    "Ret" => nil,       # look up retirement reason
    "DNS" => "Did not start",
    "NC"  => "Not classified",
    "DSQ" => "Disqualified",
    "WD"  => "Withdrew",
  }.freeze

  def initialize(race:)
    @race = race
    @drivers_cache = nil
    @constructors_cache = nil
    @statuses_cache = nil
  end

  def call
    return nil unless @race.url.present?

    title = extract_title(@race.url)
    return nil unless title

    section_number = find_race_classification_section(title)
    return nil unless section_number

    wikitext = fetch_wikitext(title, section_number)
    return nil unless wikitext

    parse_classification_table(wikitext)
  rescue StandardError => e
    Rails.logger.error("WikipediaRaceResultFetcher failed for #{@race.url}: #{e.message}")
    nil
  end

  private

  def extract_title(url)
    URI.parse(url).path.split("/wiki/").last
  rescue URI::InvalidURIError
    nil
  end

  def find_race_classification_section(title)
    uri = URI(API_BASE)
    uri.query = URI.encode_www_form(action: "parse", page: title, prop: "sections", format: "json")
    data = fetch_json(uri)
    return nil unless data

    sections = data.dig("parse", "sections") || []
    section = sections.find { |s| s["line"] =~ /race classification/i }
    section ||= sections.find { |s| s["line"] =~ /classification/i && s["line"] !~ /qualifying|sprint/i }
    section&.dig("index")
  end

  def fetch_wikitext(title, section_number)
    uri = URI(API_BASE)
    uri.query = URI.encode_www_form(action: "parse", page: title, prop: "wikitext", section: section_number, format: "json")
    data = fetch_json(uri)
    data&.dig("parse", "wikitext", "*")
  end

  def fetch_json(uri)
    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.warn("Wikipedia API request failed: #{e.message}")
    nil
  end

  def parse_classification_table(wikitext)
    # Split into rows by |- separator
    rows = wikitext.split(/^\|\-/m)
    results = []

    rows.each do |row|
      # A result row must have a scope="row" cell (the position cell)
      next unless row.include?('scope="row"')

      parsed = parse_row(row)
      next unless parsed

      results << parsed
    end

    # Fix position_order: use table row order for any entry without a data-sort-value
    results.each_with_index do |r, idx|
      r[:position_order] = idx + 1 if r[:position_order] == 99
    end

    results
  end

  def parse_row(row)
    # Extract cells: lines starting with ! or |
    cells = row.strip.split("\n").map(&:strip).reject(&:empty?)

    # Position cell starts with !
    pos_cell = cells.find { |c| c.start_with?("!") }
    return nil unless pos_cell

    # Remaining data cells start with |
    data_cells = cells.select { |c| c.start_with?("|") && !c.start_with?("|-") }
    return nil if data_cells.size < 7

    position_raw = clean_cell(pos_cell.sub(/^!\s*/, ""))
    number_raw   = clean_cell(data_cells[0])
    driver_raw   = data_cells[1]  # keep wiki markup for driver extraction
    constructor_raw = data_cells[2]  # keep wiki markup for constructor extraction
    laps_raw     = clean_cell(data_cells[3])
    time_raw     = clean_cell(data_cells[4])
    grid_raw     = clean_cell(data_cells[5])
    points_raw   = clean_cell(data_cells[6])

    # Parse position
    position, position_order, is_classified = parse_position(pos_cell)

    # Parse car number
    number = number_raw.to_i

    # Find driver
    driver = find_driver(number, driver_raw)
    return nil unless driver

    # Find constructor
    constructor = find_constructor(constructor_raw)
    return nil unless constructor

    # Parse other fields
    laps = laps_raw.to_i
    grid = parse_grid(grid_raw)
    points = parse_points(points_raw)

    # Determine status
    status = determine_status(position_raw, time_raw, laps)
    return nil unless status

    {
      driver: driver,
      constructor: constructor,
      status: status,
      position: position,
      position_order: position_order,
      points: points,
      time: is_classified ? time_raw : nil,
      laps: laps,
      grid: grid,
      number: number,
      milliseconds: nil,
      fastest_lap_time: nil,
      fastest_lap_speed: nil,
      fastest_lap: nil,
    }
  end

  def parse_position(cell)
    text = clean_cell(cell.sub(/^!\s*/, ""))

    # Extract data-sort-value for ordering non-finishers
    sort_value = cell[/data-sort-value="(\d+)"/, 1]&.to_i

    case text
    when /\A(\d+)\z/
      pos = $1.to_i
      [pos, pos, true]
    when /Ret/i
      [nil, sort_value || 99, false]
    when /DNS/i
      [nil, sort_value || 99, false]
    when /NC/i
      [nil, sort_value || 99, false]
    when /DSQ/i
      [nil, sort_value || 99, false]
    when /WD/i
      [nil, sort_value || 99, false]
    else
      # Try to extract a number
      num = text[/\d+/]
      num ? [num.to_i, num.to_i, true] : [nil, sort_value || 99, false]
    end
  end

  def parse_grid(raw)
    return 0 if raw.blank? || raw =~ /\A[\u2014\u2013\-—–]+\z/ || raw =~ /pit/i || raw == "0"
    num = raw[/\d+/]
    num ? num.to_i : 0
  end

  def parse_points(raw)
    return 0 if raw.blank?
    # Points may include decimals (e.g., sprint race half points)
    num = raw[/[\d.]+/]
    num ? num.to_f : 0
  end

  def determine_status(position_raw, time_raw, laps)
    statuses = cached_statuses

    case position_raw
    when /\A\d+\z/
      # Classified finisher
      if time_raw =~ /\+(\d+)\s+[Ll]ap/
        lap_deficit = $1.to_i
        status_text = lap_deficit == 1 ? "+1 Lap" : "+#{lap_deficit} Laps"
        statuses[status_text] || statuses["Finished"]
      else
        statuses["Finished"]
      end
    when /DNS/i
      statuses["Did not start"]
    when /NC/i
      statuses["Not classified"]
    when /DSQ/i
      statuses["Disqualified"]
    when /WD/i
      statuses["Withdrew"]
    when /Ret/i
      # Retirement — time_raw contains the reason
      reason = time_raw.strip
      statuses[reason] || statuses["Retired"] || find_fuzzy_status(reason)
    else
      statuses["Finished"]
    end
  end

  def find_fuzzy_status(reason)
    Status.where("LOWER(status_type) = ?", reason.downcase).first ||
      Status.where("LOWER(status_type) LIKE ?", "%#{reason.downcase}%").first
  end

  def find_driver(number, raw_cell)
    drivers = cached_drivers

    # Primary: match by car number
    driver = drivers[:by_number][number]
    return driver if driver

    # Fallback: extract surname from wiki link and match
    surname = extract_driver_surname(raw_cell)
    if surname
      driver = drivers[:by_surname][surname.downcase]
      return driver if driver
    end

    Rails.logger.warn("WikipediaRaceResultFetcher: Could not find driver ##{number} (#{surname})")
    nil
  end

  def extract_driver_surname(cell)
    # Match [[George Russell (racing driver)|George Russell]] or [[Fernando Alonso]]
    if cell =~ /\[\[([^|\]]+?)(?:\|([^\]]+))?\]\]/
      display = $2 || $1
      display = display.strip.gsub("'''", "")
      # Surname is the last word
      display.split.last
    end
  end

  def find_constructor(raw_cell)
    constructors = cached_constructors
    cleaned = clean_cell(raw_cell)

    # Extract all wiki link targets and display names
    links = raw_cell.scan(/\[\[([^|\]]+?)(?:\|([^\]]+))?\]\]/)

    links.each do |target, display|
      target = target.strip
      display = display&.strip

      # Skip engine suppliers
      ref = CONSTRUCTOR_MAP[target]
      next if ref.nil? && CONSTRUCTOR_MAP.key?(target)  # explicitly mapped to nil = engine supplier

      if ref
        c = constructors[ref]
        return c if c
      end

      # Try display name
      if display
        ref = CONSTRUCTOR_MAP[display]
        if ref
          c = constructors[ref]
          return c if c
        end
      end
    end

    # Fallback: try the cleaned text against constructor names
    constructors.each_value do |c|
      return c if cleaned.downcase.include?(c.name.downcase)
    end

    Rails.logger.warn("WikipediaRaceResultFetcher: Could not find constructor from: #{cleaned}")
    nil
  end

  def clean_cell(text)
    text = text.dup
    # Remove leading | or !
    text.sub!(/^[|!]\s*/, "")
    # Remove wiki templates BEFORE stripping cell prefix pipe
    # (templates like {{abbr|X|Y}} contain pipes that confuse the prefix stripper)
    text.gsub!(/\{\{flagicon\|[^}]*\}\}\s*/i, "")
    text.gsub!(/\{\{nowrap\|(.+?)\}\}/i, '\1')
    text.gsub!(/\{\{abbr\|([^|]+)\|[^}]*\}\}/i, '\1')
    text.gsub!(/\{\{ref\|[^}]*\}\}/i, "")
    text.gsub!(/\{\{[^}]*\}\}/, "")
    # Now strip style/attribute prefix: everything before the last |
    text.sub!(/^.*\|\s*/, "") if text.include?("|")
    # Remove wiki links, keeping display text
    text.gsub!(/\[\[([^|\]]+)\|([^\]]+)\]\]/, '\2')
    text.gsub!(/\[\[([^\]]+)\]\]/, '\1')
    # Remove bold/italic markup
    text.gsub!(/'{2,3}/, "")
    # Remove HTML tags
    text.gsub!(/<[^>]+>/, "")
    text.strip
  end

  def cached_drivers
    @drivers_cache ||= begin
      season_drivers = SeasonDriver.where(season: @race.season).includes(:driver).map(&:driver).compact
      all_active = season_drivers.any? ? season_drivers : Driver.where(active: true)

      by_number = all_active.index_by(&:number)
      by_surname = all_active.index_by { |d| d.surname.downcase }
      { by_number: by_number, by_surname: by_surname }
    end
  end

  def cached_constructors
    @constructors_cache ||= Constructor.all.index_by(&:constructor_ref)
  end

  def cached_statuses
    @statuses_cache ||= Status.all.index_by(&:status_type)
  end
end
