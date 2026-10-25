require "test_helper"
require "minitest/mock"

class WikipediaQualifyingResultFetcherTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
    @fetcher = WikipediaQualifyingResultFetcher.new(race: @race)
  end

  # Trimmed from the real 2026 United States GP article. Car numbers are
  # deliberately *not* the fixture drivers' numbers (Norris carries #1 here,
  # Verstappen #3) so a number-first match would attribute rows to the wrong
  # driver; the fetcher must go by name.
  def table
    <<~WIKI
      === Qualifying classification ===
      {| class="wikitable sortable" style="font-size: 85%;"
      ! rowspan="2" |{{Tooltip|Pos.|Qualifying position}}
      ! rowspan="2" |{{Tooltip|No.|Car number}}
      ! rowspan="2" |Driver
      ! rowspan="2" |Constructor
      ! colspan="3" style="background:#eaecf0; text-align:center;" |{{nowrap|Qualifying times}}
      ! rowspan="2" |{{Tooltip|Final<br />grid|Final grid position}}
      |-
      ! scope="col" |Q1
      ! scope="col" |Q2
      ! scope="col" |Q3
      |-
      ! scope="row" |1
      | align="center" |3
      |data-sort-value="ver"|{{flagicon|NED}} [[Max Verstappen]]
      |[[Red Bull Racing]]-[[Red Bull Powertrains|Red Bull Ford]]
      |1:35.215
      |1:34.471
      |'''1:34.214'''
      | align="center" |1
      |-
      !2
      | align="center" |16
      |data-sort-value="lec"|{{flagicon|MON}} [[Charles Leclerc]]
      |[[Scuderia Ferrari|Ferrari]]
      |1:35.200
      |'''1:34.198'''
      |data-sort-value="2"|No time
      | align="center" |6{{ref|1|a}}
      |-
      ! scope="row" |11
      | align="center" |1
      |data-sort-value="nor"|{{nowrap|{{flagicon|GBR}} [[Lando Norris]]}}
      |[[McLaren]]-[[Mercedes AMG High Performance Powertrains|Mercedes]]
      |1:36.001
      |style="background: silver" align="center" data-sort-value="11"|<small>N/A</small>
      |style="background: silver" align="center" data-sort-value="11"|<small>N/A</small>
      | align="center" |10
      |-
      ! data-sort-value="23" |{{abbr|WD|Withdrawn}}
      | align="center" |81
      |data-sort-value="pia"|{{flagicon|AUS}} [[Oscar Piastri]]
      |[[McLaren]]-[[Mercedes AMG High Performance Powertrains|Mercedes]]
      |style="background: silver" align="center" |<small>N/A</small>
      |style="background: silver" align="center" |<small>N/A</small>
      |style="background: silver" align="center" |<small>N/A</small>
      |style="text-align:center"|{{abbr|PL|Pit lane}}
      |- class="sortbottom"
      | colspan="8" style="background-color:#eaecf0;text-align:center" |'''[[107% rule|107% time]]: 1:41.681'''
      |- class="sortbottom"
      ! colspan="8" |Sources:<ref>{{cite web |title=Qualifying |url=https://example.com}}</ref>
      |}
      '''Notes'''
      * {{note|1|a}} – [[Charles Leclerc]] received a grid penalty.
    WIKI
  end

  test "parses positions, lap times and constructors from the real table shape" do
    rows = @fetcher.send(:parse_classification_table, table)

    assert_equal 4, rows.size
    verstappen, leclerc, norris, piastri = rows

    assert_equal drivers(:verstappen), verstappen[:driver]
    assert_equal constructors(:red_bull), verstappen[:constructor]
    assert_equal 1, verstappen[:position]
    assert_equal %w[1:35.215 1:34.471 1:34.214], verstappen.values_at(:q1, :q2, :q3)

    assert_equal drivers(:leclerc), leclerc[:driver]
    assert_equal constructors(:ferrari), leclerc[:constructor]
    assert_equal 2, leclerc[:position]
    assert_equal ["1:35.200", "1:34.198", nil], leclerc.values_at(:q1, :q2, :q3), "'No time' is not a lap time"

    assert_equal drivers(:norris), norris[:driver]
    assert_equal constructors(:mclaren), norris[:constructor]
    assert_equal 11, norris[:position]
    assert_equal ["1:36.001", nil, nil], norris.values_at(:q1, :q2, :q3), "N/A cells are not lap times"

    assert_equal drivers(:piastri), piastri[:driver]
    assert_nil piastri[:position], "a withdrawn entry has no qualifying position"
  end

  test "matches drivers by name before car number" do
    rows = @fetcher.send(:parse_classification_table, table)

    # Fixture numbers: Verstappen 1, Norris 4. In the table Norris is #1.
    assert_equal drivers(:norris), rows.find { |r| r[:position] == 11 }[:driver]
    assert_equal drivers(:verstappen), rows.find { |r| r[:position] == 1 }[:driver]
  end

  test "name matching ignores accents, suffixes and disambiguation" do
    assert_equal drivers(:verstappen), @fetcher.send(:find_driver_by_name, "[[Max Verstappen (racing driver)|Max Verstappen]]")
    assert_equal drivers(:leclerc), @fetcher.send(:find_driver_by_name, "{{flagicon|MON}} [[Charles Léclerc Jr.]]")
    assert_nil @fetcher.send(:find_driver_by_name, "[[Nobody Here]]")
  end

  test "picks the Grand Prix qualifying section, not the sprint qualifying one" do
    sections = [
      { "line" => "Sprint qualifying classification", "index" => "8" },
      { "line" => "Sprint classification", "index" => "11" },
      { "line" => "Qualifying classification", "index" => "14" },
      { "line" => "Race classification", "index" => "18" },
    ]
    payload = { "parse" => { "title" => "2026 Miami Grand Prix", "sections" => sections } }

    @fetcher.stub(:fetch_json, payload) do
      assert_equal "14", @fetcher.send(:classification_section_index, "2026_Miami_Grand_Prix")
    end
  end

  test "returns nil when the article has no qualifying classification yet" do
    payload = { "parse" => { "title" => "2026 Miami Grand Prix",
                             "sections" => [{ "line" => "Background", "index" => "1" }] } }

    @fetcher.stub(:fetch_json, payload) do
      assert_nil @fetcher.send(:classification_section_index, "2026_Miami_Grand_Prix")
    end
  end

  test "returns empty for a table with no parseable rows" do
    assert_equal [], @fetcher.send(:parse_classification_table, "=== Qualifying classification ===\n{|\n|}\n")
  end
end
