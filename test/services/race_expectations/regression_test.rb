require "test_helper"
require_relative "../../support/race_expectation_history"

class RaceExpectations::RegressionTest < ActiveSupport::TestCase
  include RaceExpectationHistory

  test "learns both inputs instead of hardcoding an Elo qualifying blend" do
    samples = expectation_history.flat_map { |event| event[:samples] }
    model = RaceExpectations::Regression.fit(samples)
    assert_in_delta 0.3, model[:weights][:elo], 0.01
    assert_in_delta 0.5, model[:weights][:qualifying], 0.01
    assert_in_delta 0.08, model[:intercept], 0.01
  end

  test "worse qualifying increases the estimate for the same Elo and vice versa" do
    model = RaceExpectations::Regression.fit(expectation_history.flat_map { |event| event[:samples] })
    best = RaceExpectations::Regression.predict(model, elo: 0.2, qualifying: 0.2)
    assert_operator RaceExpectations::Regression.predict(model, elo: 0.2, qualifying: 0.8), :>, best
    assert_operator RaceExpectations::Regression.predict(model, elo: 0.8, qualifying: 0.2), :>, best
  end

  test "constant and collinear samples remain finite" do
    samples = Array.new(250) { { elo: 0.5, qualifying: 0.5, finish: 0.4 } }
    model = RaceExpectations::Regression.fit(samples)
    assert_in_delta 0.4, RaceExpectations::Regression.predict(model, elo: 0.5, qualifying: 0.5)
    assert model[:weights].values.all?(&:finite?)
    assert_nil RaceExpectations::Regression.fit([])
  end

  test "predictions are bounded to the field and slopes are nonnegative" do
    samples = expectation_history.flat_map { |event| event[:samples] }.map { |sample| sample.merge(finish: 1 - sample[:elo]) }
    model = RaceExpectations::Regression.fit(samples)
    assert model[:weights].values.all? { |weight| weight >= 0 }
    assert RaceExpectations::Regression.predict(model, elo: 0, qualifying: 0).between?(0, 1)
  end
end
