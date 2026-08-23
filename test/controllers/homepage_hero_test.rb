require "test_helper"

# Every homepage phase used to render its own near-identical hero partial, and
# only two of them ever got the v2 layout — race day silently kept the old one
# for months. The partials are now unified; this pins each phase to the hero it
# should render so a future divergence fails loudly instead of shipping.
class HomepageHeroTest < ActionDispatch::IntegrationTest
  # melbourne_2026 is 2026-03-22 14:00 with no results; bahrain_2026 has results.
  PHASES = {
    between_races: { at: "2026-03-15 12:00",  tone: "weekend-hero-ahead", column: :schedule },
    pre_race:      { at: "2026-03-18 12:00",  tone: "weekend-hero-ahead", column: :schedule },
    race_weekend:  { at: "2026-03-21 12:00",  tone: "weekend-hero-open",  column: :schedule },
    race_day:      { at: "2026-03-22 10:00",  tone: "weekend-hero-live",  column: :schedule },
    race_complete: { at: "2026-03-22 18:00",  tone: "weekend-hero-done",  column: :schedule },
    post_race:     { at: "2026-03-09 12:00",  tone: "weekend-hero-done",  column: :podium },
  }.freeze

  PHASES.each do |phase, expected|
    test "#{phase} renders the shared v2 weekend hero" do
      travel_to Time.zone.parse(expected[:at]) do
        get root_path
        assert_response :success

        # between_races keeps its own deliberately calmer hero; every other
        # race-context phase goes through pages/_hero_weekend.
        if phase == :between_races
          assert_select ".page-hero.between-races-hero", 1
          next
        end

        assert_select ".page-hero.weekend-hero-v2", 1,
                      "#{phase} should render the shared weekend hero"
        assert_select ".page-hero.#{expected[:tone]}", 1,
                      "#{phase} should carry the #{expected[:tone]} phase tone"
        assert_select ".weekend-hero-watermark img", 1,
                      "#{phase} should show the circuit track watermark"

        case expected[:column]
        when :schedule
          assert_select ".weekend-hero-schedule", 1
          assert_select ".weekend-hero-podium", 0
        when :podium
          assert_select ".weekend-hero-podium", 1
          assert_select ".weekend-hero-schedule", 0
        end
      end
    end
  end

  test "no phase falls through to a bare hero-less homepage" do
    PHASES.each_value do |expected|
      travel_to Time.zone.parse(expected[:at]) do
        get root_path
        assert_select ".page-hero, .hero-intro", { minimum: 1 },
                      "no hero rendered at #{expected[:at]}"
      end
    end
  end
end
