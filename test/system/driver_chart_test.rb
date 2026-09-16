require "application_system_test_case"

class DriverChartTest < ApplicationSystemTestCase
  setup do
    @driver = drivers(:verstappen)
    @driver.update!(first_race_date: races(:melbourne_2025).date,
                    last_race_date: races(:melbourne_2026).date, color: "#3571c6")
    template = race_results(:bahrain_2026_verstappen)
    [[races(:melbourne_2025), 3, 2350], [races(:melbourne_2026), 2, 2420]].each do |race, position, elo|
      template.dup.tap do |result|
        result.assign_attributes(race: race, position: position, position_order: position, new_elo_v2: elo)
        result.save!
      end
    end
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  [320, 390].each do |width|
    test "driver chart uses the available plot width on a #{width}px phone" do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                     width: width, height: 844, deviceScaleFactor: 1, mobile: true)
      visit driver_path(@driver)
      wait_for_chart

      assert_equal width, page.evaluate_script("window.innerWidth")
      assert_wide_single_driver_chart
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width

      FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
      page.execute_script(<<~JS)
        window.scrollTo({
          top: document.querySelector('.chart-header').getBoundingClientRect().top + window.scrollY - 80,
          behavior: 'instant'
        });
      JS
      assert_operator page.evaluate_script("document.querySelector('.driver-chart-full').getBoundingClientRect().top"), :<, 200
      page.save_screenshot(Rails.root.join("tmp/screenshots/driver-chart-#{width}.png"))
    end
  end

  test "desktop driver chart keeps podium markers and race tooltips" do
    visit driver_path(@driver)
    wait_for_chart
    assert_wide_single_driver_chart

    markers = chart_value("chart.getOption().series[0].markPoint.data")
    %w[Win P2 P3].each do |label|
      assert markers.any? { |point| point["value"].to_s.start_with?("#{label} —") }
    end

    chart_value(<<~JS)
      chart.dispatchAction({
        type: 'showTip', seriesIndex: 0,
        dataIndex: chart.getOption().series[0].data.findIndex(point => point.value === 2420)
      })
    JS
    assert_text "Finished 2nd"
    assert_text "2420 Elo"
  end

  private

  def wait_for_chart
    assert_selector ".driver-chart-full [_echarts_instance_] canvas"
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
      chart_value("chart.getOption().series.length > 0")
    end
    # Capture the final line and markers, not an intermediate animation frame.
    chart_value("chart.setOption({ animation: false })")
  end

  def assert_wide_single_driver_chart
    geometry = chart_value(<<~JS)
      (() => {
        const rect = chart.getModel().getComponent('grid').coordinateSystem.getRect();
        return { width: chart.getWidth(), plotWidth: rect.width, leftGap: rect.x,
                 rightGap: chart.getWidth() - rect.x - rect.width };
      })()
    JS
    assert_in_delta 16, geometry["rightGap"], 1
    assert_in_delta 48, geometry["leftGap"], 1
    assert_operator geometry["plotWidth"], :>, geometry["width"] * 0.75
    assert_equal false, chart_value("chart.getOption().series[0].endLabel.show")
    assert_equal false, chart_value("chart.getOption().legend[0].show")
  end

  def chart_value(expression)
    page.evaluate_script(<<~JS)
      (() => {
        const element = document.querySelector('.driver-chart-full [_echarts_instance_]');
        const chart = window.echarts.getInstanceByDom(element);
        return #{expression};
      })()
    JS
  end
end
