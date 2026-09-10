require "test_helper"

class Fantasy::RacePickPayloadTest < ActiveSupport::TestCase
  setup do
    @race = races(:melbourne_2026)
    @verstappen = drivers(:verstappen)
    @norris = drivers(:norris)
  end

  test "normalizes a valid browser payload" do
    result = Fantasy::RacePickPayload.new(raw: [
      { driver_id: @verstappen.id.to_s, position: "1", source: "manual" },
      { driver_id: @norris.id, position: 2, source: "random" }
    ].to_json, race: @race).call

    assert result.success?
    assert_equal [@verstappen.id, @norris.id], result.picks.map { |pick| pick["driver_id"] }
    assert_equal %w[manual random], result.picks.map { |pick| pick["source"] }
  end

  test "rejects duplicate drivers" do
    result = Fantasy::RacePickPayload.new(raw: [
      { driver_id: @verstappen.id, position: 1, source: "manual" },
      { driver_id: @verstappen.id, position: 2, source: "manual" }
    ], race: @race).call

    refute result.success?
    assert_match(/driver.*once/i, result.error)
  end

  test "rejects duplicate or skipped positions" do
    duplicate = Fantasy::RacePickPayload.new(raw: [
      { driver_id: @verstappen.id, position: 1, source: "manual" },
      { driver_id: @norris.id, position: 1, source: "manual" }
    ], race: @race).call
    skipped = Fantasy::RacePickPayload.new(raw: [
      { driver_id: @verstappen.id, position: 2, source: "manual" }
    ], race: @race).call

    refute duplicate.success?
    refute skipped.success?
  end

  test "rejects invalid JSON and drivers outside the season grid" do
    invalid_json = Fantasy::RacePickPayload.new(raw: "{broken", race: @race).call
    old_driver = Driver.create!(driver_ref: "outside-grid", forename: "Test", surname: "Reserve")
    outside_grid = Fantasy::RacePickPayload.new(raw: [
      { driver_id: old_driver.id, position: 1, source: "manual" }
    ], race: @race).call

    refute invalid_json.success?
    refute outside_grid.success?
    assert_match(/not on this season/i, outside_grid.error)
  end
end
