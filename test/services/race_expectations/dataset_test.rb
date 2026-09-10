require "test_helper"

class RaceExpectations::DatasetTest < ActiveSupport::TestCase
  test "joins qualifying to drivers and uses only pre-race Elo and classified targets" do
    event = RaceExpectations::Dataset.event(races(:bahrain_2026))
    assert_equal 3, event[:samples].size
    assert event[:samples].any? { |sample| sample[:elo].zero? && sample[:qualifying].zero? && sample[:finish].zero? }
    drivers(:verstappen).update_columns(elo_v2: 1000)
    race_results(:bahrain_2026_verstappen).update_columns(new_elo_v2: 9999)
    assert_equal event, RaceExpectations::Dataset.event(races(:bahrain_2026))
  end

  test "query excludes target day future and cancelled races" do
    race = races(:bahrain_2026)
    assert_empty RaceExpectations::Dataset.before(race.date)
    assert_equal [race.id], RaceExpectations::Dataset.before(race.date + 1).map { |event| event[:id] }
    race.update!(cancelled: true)
    assert_empty RaceExpectations::Dataset.before(race.date + 1)
  end

  test "missing qualifying is not substituted from starting grid" do
    race = races(:bahrain_2026)
    race.qualifying_results.destroy_all
    assert_nil RaceExpectations::Dataset.event(race.reload)
  end

  test "a missing pre-race rating prevents distorted field rankings" do
    race_results(:bahrain_2026_piastri).update!(old_elo_v2: nil)
    assert_nil RaceExpectations::Dataset.event(races(:bahrain_2026))
  end

  test "history loads bounded separate queries instead of multiplying qualifying and result rows" do
    race = races(:bahrain_2026)
    expected = RaceExpectations::Dataset.event(race)
    queries = []
    subscriber = ->(event) do
      payload = event.payload
      queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached]
    end

    events = nil
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        events = RaceExpectations::Dataset.before(race.date + 1)
      end
    end

    assert_equal [expected], events
    assert_operator queries.size, :<=, 4, "History should load races, qualifying, results and statuses once each"
    assert queries.any? { |sql| sql.match?(/FROM "qualifying_results"/) }, "Qualifying should be preloaded separately"
    assert queries.any? { |sql| sql.match?(/FROM "race_results"/) }, "Results should be preloaded separately"
    assert_not queries.any? { |sql| sql.match?(/JOIN "qualifying_results"/) && sql.match?(/JOIN "race_results"/) },
               "Do not recreate the qualifying × results eager-load join"
  end
end
