require "test_helper"

class RaceAnalysisHelperTest < ActionView::TestCase
  test "signed values distinguish missing zero gains and losses" do
    assert_equal "—", analysis_signed(nil)
    assert_equal "+12.3", analysis_signed(12.34, precision: 1)
    assert_equal "−12.3", analysis_signed(-12.34, precision: 1)
    assert_equal "0.0", analysis_signed(-0.01, precision: 1)
    assert_equal "neutral", analysis_tone(nil)
    assert_equal "1.5", analysis_seed(1.5)
    assert_equal "1", analysis_seed(1.0)
  end
end
