require "test_helper"

class RaceDetailsHelperTest < ActionView::TestCase
  include ApplicationHelper
  test "missing sessions distinguish future pending historical and unknown schedule" do
    race = races(:melbourne_2026)
    travel_to race.starts_at - 1.hour do
      assert_match /has not started/, missing_session_message(race, :race)
    end
    travel_to race.starts_at + 3.hours do
      assert_match /Awaiting race results/, missing_session_message(race, :race)
    end
    travel_to race.starts_at + 2.days do
      assert_match /unavailable.*our data/, missing_session_message(race, :race)
    end
    race.time = nil
    travel_to race.date.beginning_of_day do
      assert_match /time is not recorded/, missing_session_message(race, :race)
    end
  end

  test "details avoid inferred qualifying times and unclassified position gains" do
    qualifying = qualifying_results(:lec_bahrain_2026)
    fields = result_detail_fields(qualifying, session: :qualifying, constructor: qualifying.constructor)
    assert_equal "No time recorded", fields["Q3"]
    assert_equal qualifying.q1, fields["Q1"]
    dnf = race_results(:bahrain_2026_piastri)
    fields = result_detail_fields(dnf, session: :race, constructor: dnf.constructor)
    assert_equal "—", fields["Places gained"]
    assert_equal dnf.status.status_type, fields["Status"]
  end
end
