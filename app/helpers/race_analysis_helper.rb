module RaceAnalysisHelper
  def analysis_signed(value, precision: 0)
    return "—" if value.nil?

    rounded = value.round(precision)
    formatted = number_with_precision(rounded.abs, precision: precision)
    return formatted if rounded.zero?

    "#{rounded.positive? ? '+' : '−'}#{formatted}"
  end

  def analysis_tone(value)
    return "neutral" if value.nil? || value.zero?

    value.positive? ? "positive" : "negative"
  end

  def analysis_seed(value)
    number_with_precision(value, precision: 1, strip_insignificant_zeros: true)
  end

  # Decorative only: precise expected/actual positions and bounds remain text.
  def expectation_lane_style(assessment, field_size)
    scale = 100.0 / [field_size - 1, 1].max
    expected = (assessment.expected - 1) * scale
    finish = (assessment.result.position_order.to_i - 1) * scale
    left = ((assessment.low || assessment.expected) - 1) * scale
    width = ((assessment.high || assessment.expected) - (assessment.low || assessment.expected)) * scale
    "--expected: #{expected.clamp(0, 100)}%; --finish: #{finish.clamp(0, 100)}%; " \
      "--range-left: #{left.clamp(0, 100)}%; --range-width: #{width.clamp(0, 100)}%;"
  end
end
