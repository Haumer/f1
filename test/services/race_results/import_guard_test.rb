require 'test_helper'

class RaceResults::ImportGuardTest < ActiveSupport::TestCase
  setup do
    @race = races(:melbourne_2026)
    @guard = RaceResults::ImportGuard.new(race: @race)
  end

  test 'requires matching season round date and circuit' do
    event = { 'season' => @race.year.to_s, 'round' => @race.round.to_s,
              'date' => @race.date.iso8601, 'Circuit' => { 'circuitId' => @race.circuit.circuit_ref } }
    assert_nil @guard.validate_event!(event)
    %w[season round date Circuit].each do |field|
      invalid = event.merge(field => field == 'Circuit' ? { 'circuitId' => 'monza' } : 'wrong')
      assert_raises(RaceResults::ImportGuard::Rejected) { @guard.validate_event!(invalid) }
    end
  end

  test 'rejects duplicate and unknown drivers before any writes' do
    assert_raises(RaceResults::ImportGuard::Rejected) { @guard.validate_rows!([{ driver_id: 1 }, { driver_id: 1 }]) }
    assert_raises(RaceResults::ImportGuard::Rejected) { @guard.validate_rows!([{ driver_id: nil }]) }
  end

  test 'rejects a copied field even if two placeholder rows have been edited' do
    earlier = races(:bahrain_2026)
    earlier.race_results.delete_all
    10.times do |i|
      driver = Driver.create!(driver_ref: "copy_test_#{i}", surname: "Driver#{i}", forename: 'Test')
      RaceResult.create!(race: earlier, driver: driver, constructor: constructors(:mclaren),
                         status: statuses(:finished), position: i + 1, position_order: i + 1, laps: 53, points: 0)
    end
    rows = earlier.race_results.reload.map { |r| r.attributes.symbolize_keys.slice(:driver_id, :position_order, :laps) }
    rows.first(2).each { |r| r[:laps] = 57 }
    error = assert_raises(RaceResults::ImportGuard::Rejected) { @guard.validate_rows!(rows) }
    assert_includes error.message, 'duplicates round 1'
    rows.each { |r| r[:laps] = 57 }
    assert_nil @guard.validate_rows!(rows)
  end
end
