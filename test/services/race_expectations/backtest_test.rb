require "test_helper"
require_relative "../../support/race_expectation_history"

class RaceExpectations::BacktestTest < ActiveSupport::TestCase
  include RaceExpectationHistory

  test "target day and future outcomes cannot alter the profile" do
    history = expectation_history
    cutoff = history[30][:date]
    first = RaceExpectations::Backtest.profile(history, before: cutoff)
    changed = history.map do |event|
      event[:date] >= cutoff ? event.merge(samples: event[:samples].map { |sample| sample.merge(finish: 0.99) }) : event
    end
    assert_equal first, RaceExpectations::Backtest.profile(changed, before: cutoff)
    assert_equal 30, first[:races]
    assert_operator first[:last_date], :<, cutoff
  end

  test "a held out race cannot improve its own fit" do
    history = expectation_history(count: 21)
    check = RaceExpectations::Backtest.evaluate(history)
    changed = history.map.with_index do |event, i|
      i == 20 ? event.merge(samples: event[:samples].map { |sample| sample.merge(finish: 1.0) }) : event
    end
    worse = RaceExpectations::Backtest.evaluate(changed)
    assert_equal 1, check[:races]
    assert_equal 20, check[:finishes]
    assert_operator worse[:mae][:combined], :>, check[:mae][:combined]
    assert_nil check[:radius], "A single checked race must not supply a range"
  end

  test "compares identically held out samples and learns a usable error envelope" do
    check = RaceExpectations::Backtest.evaluate(expectation_history)
    assert_equal 25, check[:races]
    assert_equal 500, check[:finishes]
    assert_operator check[:mae][:combined], :<, check[:mae][:elo]
    assert_operator check[:mae][:combined], :<, check[:mae][:qualifying]
    assert_operator check[:radius], :>, 0
  end

  test "insufficient and out of window history is withheld" do
    history = expectation_history(count: 19)
    assert_nil RaceExpectations::Backtest.profile(history, before: Date.new(2026, 1, 1))[:model]
    assert_nil RaceExpectations::Backtest.profile(expectation_history, before: Date.new(2040, 1, 1))[:model]
  end
end
