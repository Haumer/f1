require "test_helper"

class Graphs::LineTest < ActiveSupport::TestCase
  test "single-driver chart does not reserve space for redundant identification" do
    data = Graphs::Line.new(driver: drivers(:verstappen)).driver_data

    assert_equal false, data.dig(:series, 0, :endLabel, :show)
    assert_equal false, data.dig(:legend, :show)
    assert_equal 48, data.dig(:grid, :left)
    assert_equal 16, data.dig(:grid, :right)
    assert_equal "Verstappen", data.dig(:series, 0, :name)
  end

  test "podium markers keep their coordinates colors and values" do
    { verstappen: [1, "Win"], norris: [2, "P2"], leclerc: [3, "P3"] }.each do |driver_key, (position, label)|
      driver = drivers(driver_key)
      result = driver.race_results.first
      data = Graphs::Line.new(driver: driver).driver_data
      markers = data.dig(:series, 0, :markPoint, :data)
      podium = markers.find { |point| point[:value] == "#{label} — #{result.race.circuit.name}" }

      assert podium, "Expected the #{label} medal to remain on the chart"
      assert_equal result.display_new_elo, podium[:coord].last
      assert_includes data.dig(:xAxis, :data), podium[:coord].first
      assert_equal Race::PODIUM_COLORS[position], podium.dig(:itemStyle, :color)
    end
  end

  test "chart retains race details zoom and peak annotations" do
    data = Graphs::Line.new(driver: drivers(:verstappen)).driver_data

    assert_equal "axis", data.dig(:tooltip, :trigger)
    assert_kind_of RailsCharts::Javascript, data.dig(:tooltip, :formatter)
    assert_equal "slider", data.dig(:dataZoom, 0, :type)
    assert data.dig(:series, 0, :markLine, :data).any? { |mark| mark[:type] == "max" }
    assert data.dig(:series, 0, :data).any? { |point| point[:name].include?("1st - 2400") }
  end

  test "comparison charts still identify each driver" do
    compared = [drivers(:verstappen), drivers(:norris)]
    compared.each do |driver|
      driver.assign_attributes(first_race_date: races(:bahrain_2026).date, last_race_date: races(:bahrain_2026).date)
    end
    data = Graphs::Compare.new(drivers: compared).data

    assert_equal 2, data[:series].size
    assert data[:series].all? { |series| series.dig(:endLabel, :show) }
    assert_equal true, data.dig(:legend, :show)
  end
end
