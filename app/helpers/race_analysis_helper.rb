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

  # Visual lane is decorative; the exact seed, result and change remain text.
  def analysis_lane_style(row, field_size)
    start = (row.seed - 1) * 100.0 / [field_size - 1, 1].max
    finish = (row.result.position_order - 1) * 100.0 / [field_size - 1, 1].max
    "--seed: #{start.clamp(0, 100)}%; --finish: #{finish.clamp(0, 100)}%; " \
      "--left: #{[start, finish].min.clamp(0, 100)}%; --distance: #{(start - finish).abs.clamp(0, 100)}%;"
  end
end
