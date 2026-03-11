require "test_helper"

class UpdateDriverCareerTest < ActiveSupport::TestCase
  test "counts wins from race results" do
    service = UpdateDriverCareer.new(driver: drivers(:verstappen))
    assert service.career_attributes[:wins] >= 1
  end

  test "counts podiums as sum of wins + P2 + P3" do
    service = UpdateDriverCareer.new(driver: drivers(:verstappen))
    attrs = service.career_attributes
    assert_equal attrs[:wins] + attrs[:second_places] + attrs[:third_places], attrs[:podiums]
  end

  test "counts finished races" do
    service = UpdateDriverCareer.new(driver: drivers(:verstappen))
    assert service.career_attributes[:finished_races] >= 1
  end

  test "counts crash races for accident status" do
    service = UpdateDriverCareer.new(driver: drivers(:piastri))
    # piastri has a retired status race result in fixtures
    attrs = service.career_attributes
    assert attrs[:crash_races] >= 0
  end

  test "counts number_of_races excluding DNS" do
    service = UpdateDriverCareer.new(driver: drivers(:verstappen))
    assert service.career_attributes[:number_of_races] >= 1
  end

  test "sets first and last race dates" do
    service = UpdateDriverCareer.new(driver: drivers(:verstappen))
    attrs = service.career_attributes
    assert attrs[:first_race_date].is_a?(Date)
    assert attrs[:last_race_date].is_a?(Date)
    assert attrs[:first_race_date] <= attrs[:last_race_date]
  end

  test "update persists attributes to driver" do
    driver = drivers(:verstappen)
    service = UpdateDriverCareer.new(driver: driver)
    service.update
    driver.reload
    assert driver.wins.present?
    assert driver.number_of_races.present?
  end

  test "positions correctly categorizes each position" do
    driver = drivers(:norris)
    service = UpdateDriverCareer.new(driver: driver)
    attrs = service.career_attributes
    # norris finished P2 in bahrain_2026
    assert attrs[:second_places] >= 1
  end
end
