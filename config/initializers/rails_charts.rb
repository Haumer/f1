RailsCharts.options[:theme] = "dark"

# Fix encoding clash: Base64.decode64 returns ASCII-8BIT which breaks
# gsub! on UTF-8 JSON strings when driver names contain non-ASCII chars (e.g. Hülkenberg)
module RailsCharts
  class BaseChart
    def option
      str = build_options.to_json
      str.gsub!(CHART_JS_PATTERN) { Base64.decode64($1).force_encoding("UTF-8") }
      str
    end
  end
end
