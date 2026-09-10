require "test_helper"

class Standings::ConstructorTableTest < ActiveSupport::TestCase
  test "calculates live standings from the constructor on each result" do
    rows = Standings::ConstructorTable.new(
      season: seasons(:season_2026),
      race: races(:bahrain_2026)
    ).call

    assert_equal %w[McLaren Red\ Bull Ferrari], rows.map { |row| row[:constructor].name }
    assert_equal [30, 25, 15], rows.map { |row| row[:points] }
    assert_equal [1, 2, 3], rows.map { |row| row[:position] }
    assert_equal :calculated, rows.first[:source]
    assert_equal 1, rows.first[:seconds]
  end

  test "uses authoritative imported standings even when points order differs" do
    race = races(:bahrain_2026)
    race.update!(kaggle_id: 99)
    ConstructorStanding.create!(race: race, constructor: constructors(:ferrari), position: 1, points: 40, wins: 0)
    ConstructorStanding.create!(race: race, constructor: constructors(:mclaren), position: 2, points: 50, wins: 1)
    ConstructorStanding.create!(race: race, constructor: constructors(:red_bull), position: 11, points: 100, wins: 4)

    rows = Standings::ConstructorTable.new(season: seasons(:season_2026), race: race).call

    assert_equal %w[Ferrari McLaren Red\ Bull], rows.map { |row| row[:constructor].name }
    assert_equal [1, 2, 11], rows.map { |row| row[:position] }
    assert rows.all? { |row| row[:source] == :official }
  end
end
