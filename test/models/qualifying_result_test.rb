require "test_helper"

class QualifyingResultTest < ActiveSupport::TestCase
  test "belongs to race" do
    qr = qualifying_results(:ver_bahrain_2026)
    assert_equal races(:bahrain_2026), qr.race
  end

  test "belongs to driver" do
    qr = qualifying_results(:ver_bahrain_2026)
    assert_equal drivers(:verstappen), qr.driver
  end

  test "belongs to constructor" do
    qr = qualifying_results(:ver_bahrain_2026)
    assert_equal constructors(:red_bull), qr.constructor
  end

  test "sorted scope orders by position" do
    results = QualifyingResult.where(race: races(:bahrain_2026)).sorted
    assert_equal [1, 2, 3, 4], results.map(&:position)
  end

  test "best_time returns q3 when present" do
    qr = qualifying_results(:ver_bahrain_2026)
    assert_equal "1:28.789", qr.best_time
  end

  test "best_time returns q2 when q3 is blank" do
    qr = qualifying_results(:lec_bahrain_2026)
    assert_equal "1:29.600", qr.best_time
  end

  test "best_time returns q1 when q2 and q3 are blank" do
    qr = qualifying_results(:pia_bahrain_2026)
    assert_equal "1:31.000", qr.best_time
  end

  test "gap_to calculates positive gap" do
    qr = qualifying_results(:nor_bahrain_2026)
    pole_time = qualifying_results(:ver_bahrain_2026).best_time
    gap = qr.gap_to(pole_time)
    assert_equal "0.293", gap
  end

  test "gap_to returns nil when best_time is nil" do
    qr = QualifyingResult.new
    assert_nil qr.gap_to("1:28.789")
  end

  test "gap_to returns nil when other_time is nil" do
    qr = qualifying_results(:ver_bahrain_2026)
    assert_nil qr.gap_to(nil)
  end
end
