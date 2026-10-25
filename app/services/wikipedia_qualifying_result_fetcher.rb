# Parses the "Qualifying classification" table of a Grand Prix article on
# Wikipedia. Used as the fallback source when Jolpica has not yet published a
# race weekend's qualifying (it typically lags Wikipedia by a day or more).
#
# Reuses the race-result fetcher's HTTP, section, constructor and cell
# helpers; only the section choice and row shape differ:
#
#   ! scope="row" |1
#   | align="center" |12
#   |data-sort-value="ant"|{{flagicon|ITA}} [[Kimi Antonelli]]
#   |[[Mercedes-Benz in Formula One|Mercedes]]
#   |1:35.390
#   |1:34.278
#   |'''1:34.035'''
#   | align="center" |1          <- final grid; optional, ignored
#
# Drivers are matched by name first, car number second: Driver#number is not
# synced season to season, so a number alone can point at the wrong driver.
class WikipediaQualifyingResultFetcher < WikipediaRaceResultFetcher
  LAP_TIME = /\A\d{1,2}:\d{2}\.\d{3}\z/

  private

  def classification_section_index(title)
    find_section_index(title) do |sections|
      # Anchor to the start of the heading so a sprint weekend's "Sprint
      # qualifying classification" never wins over the Grand Prix qualifying.
      sections.find { |s| s["line"] =~ /\Aqualifying classification\z/i } ||
        sections.find { |s| s["line"] =~ /\Aqualifying/i && s["line"] =~ /classification|result/i }
    end
  end

  def section_label
    "Qualifying classification"
  end

  def parse_row(row)
    cells = row.strip.split("\n").map(&:strip).reject(&:empty?)

    pos_cell = cells.find { |c| c.start_with?("!") }
    return nil unless pos_cell

    data_cells = cells.select { |c| c.start_with?("|") && !c.start_with?("|-", "|}") }
    # No., Driver, Constructor, Q1, Q2, Q3 (+ an optional final-grid column)
    return nil if data_cells.size < 6

    number_raw      = clean_cell(data_cells[0])
    driver_raw      = data_cells[1]
    constructor_raw = data_cells[2]

    driver = find_driver_by_name(driver_raw) || find_driver(number_raw.to_i, driver_raw)
    return nil unless driver

    constructor = find_constructor(constructor_raw)
    return nil unless constructor

    {
      driver: driver,
      constructor: constructor,
      position: parse_qualifying_position(pos_cell),
      q1: parse_lap_time(data_cells[3]),
      q2: parse_lap_time(data_cells[4]),
      q3: parse_lap_time(data_cells[5]),
    }
  end

  # "1" -> 1. Non-classified rows (WD, DNQ, DNS, "—") have no position.
  def parse_qualifying_position(cell)
    text = clean_cell(cell)
    text[/\A\d+\z/]&.to_i
  end

  # "1:34.035" -> "1:34.035"; "N/A", "No time", "—", "" -> nil
  def parse_lap_time(cell)
    text = clean_cell(cell)
    text =~ LAP_TIME ? text : nil
  end

  def find_driver_by_name(raw_cell)
    match = raw_cell.match(/\[\[([^|\]]+?)(?:\|([^\]]+))?\]\]/)
    return nil unless match

    display = (match[2] || match[1]).gsub(/\s*\([^)]*\)/, "").gsub("'''", "")
    full = normalize_name(display)
    return nil if full.blank?

    pool = drivers_by_name
    pool[:by_full_name][full] ||
      pool[:by_surname][full.split.reject { |w| w =~ /\A(jr|sr|ii|iii)\z/ }.last]
  end

  def drivers_by_name
    @drivers_by_name ||= begin
      season_drivers = SeasonDriver.where(season: @race.season).includes(:driver).map(&:driver).compact
      pool = season_drivers.any? ? season_drivers : Driver.where(active: true).to_a

      {
        by_full_name: pool.index_by { |d| normalize_name("#{d.forename} #{d.surname}") },
        by_surname: pool.index_by { |d| normalize_name(d.surname) },
      }
    end
  end

  # "Nico Hülkenberg" and "Nico Hulkenberg" must compare equal, as must
  # "Sergio Pérez" and "Sergio Perez".
  def normalize_name(text)
    ActiveSupport::Inflector.transliterate(text.to_s).downcase.gsub(/[^a-z ]/, " ").squish
  end
end
