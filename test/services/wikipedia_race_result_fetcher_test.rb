require "test_helper"

# Regression cover for the 2026 Italian GP outage: the parser required every
# result row to carry `scope="row"`, but that attribute is optional on Wikipedia
# and editors are inconsistent. The Belgian GP table had it on all 22 rows; the
# Hungarian, Dutch and Italian tables had it zero times. Those tables parsed to
# nothing, and a fully-published classification surfaced as "no results
# available from any source".
class WikipediaRaceResultFetcherTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
    @fetcher = WikipediaRaceResultFetcher.new(race: @race)
  end

  # Two spellings of the same two-driver classification. The only difference is
  # whether the position cell carries `scope="row"`.
  def table(scoped:)
    pos = ->(n) { scoped ? %(! scope="row" |#{n}) : "!#{n}" }
    <<~WIKI
      === Race classification ===
      {| class="wikitable sortable" style="font-size: 85%;"
      ! scope="col" |Pos.
      ! scope="col" |No.
      ! scope="col" |Driver
      ! scope="col" |Constructor
      ! scope="col" |Laps
      ! scope="col" |Time/Retired
      ! scope="col" |Grid
      ! scope="col" |Points
      |-
      #{pos.call(1)}
      | align="center" |1
      |{{flagicon|NED}} '''[[Max Verstappen]]'''
      |'''[[Red Bull Racing|Red Bull]]'''
      |53
      |1:30:00.000
      | align="center" |1
      |align="center" |'''25'''
      |-
      #{pos.call(2)}
      | align="center" |4
      |{{flagicon|GBR}} [[Lando Norris]]
      |[[McLaren]]
      |53
      |+5.123
      | align="center" |2
      |align="center" |18
      |}
    WIKI
  end

  test "parses a classification table whose rows carry scope=row" do
    rows = @fetcher.send(:parse_classification_table, table(scoped: true))

    assert_equal 2, rows.size
    assert_equal [1, 2], rows.map { |r| r[:position] }
    assert_equal [25.0, 18.0], rows.map { |r| r[:points] }
    assert_equal drivers(:verstappen), rows.first[:driver]
    assert_equal drivers(:norris), rows.second[:driver]
  end

  # The actual regression: this table is what Wikipedia served for Monza 2026.
  test "parses a classification table whose rows omit scope=row" do
    rows = @fetcher.send(:parse_classification_table, table(scoped: false))

    assert_equal 2, rows.size, "bare `!1` position cells must still parse"
    assert_equal [1, 2], rows.map { |r| r[:position] }
    assert_equal [25.0, 18.0], rows.map { |r| r[:points] }
    assert_equal drivers(:verstappen), rows.first[:driver]
    assert_equal drivers(:norris), rows.second[:driver]
  end

  test "both markup styles yield identical results" do
    scoped   = @fetcher.send(:parse_classification_table, table(scoped: true))
    unscoped = @fetcher.send(:parse_classification_table, table(scoped: false))

    comparable = ->(rows) { rows.map { |r| r.slice(:position, :position_order, :points, :laps, :grid, :number) } }
    assert_equal comparable.call(scoped), comparable.call(unscoped)
  end

  test "the header row is not mistaken for a result" do
    rows = @fetcher.send(:parse_classification_table, table(scoped: false))

    # 8 `! scope="col"` header cells sit above the first `|-`; none of them may
    # survive. parse_row's >= 7 data-cell requirement is what rejects them.
    assert_equal 2, rows.size
    assert rows.none? { |r| r[:driver].nil? }
  end

  test "returns empty for a table with no parseable rows" do
    assert_equal [], @fetcher.send(:parse_classification_table, "=== Race classification ===\n{|\n|}\n")
  end
end
