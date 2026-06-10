class OgPreviewGenerator
  PODIUM_COLORS = { 1 => "#FFD700", 2 => "#C0C0C0", 3 => "#CD7F32" }.freeze
  TXT = "#e0e0e0"
  DIM = "#888888"
  W = 1200
  H = 630

  def initialize(prediction)
    @prediction = prediction
    @race = prediction.race
    @user = prediction.user
  end

  def generate
    results = @prediction.predicted_results.sort_by { |r| r["position"] }.first(10)
    driver_ids = results.map { |r| r["driver_id"] }
    drivers = Driver.where(id: driver_ids).index_by(&:id)
    sd_index = SeasonDriver.where(season: @race.season, driver_id: driver_ids)
                           .includes(:constructor).index_by(&:driver_id)

    args = ["-size", "#{W}x#{H}", "xc:#1a1a2e"]
    args.concat(top_bar)
    args.concat(branding)
    args.concat(round_info)
    args.concat(circuit_title)
    args.concat(author_line)
    args.concat(divider)

    results.each_with_index do |entry, i|
      driver = drivers[entry["driver_id"]]
      next unless driver
      args.concat(driver_row(entry, driver, sd_index[driver.id], i))
    end

    args.concat(footer)

    output = Tempfile.new(["og-preview", ".png"])
    args << "png:#{output.path}"
    system(magick_bin, *args, exception: true)
    output
  end

  private

  def magick_bin
    @magick_bin ||= system("which", "magick", out: File::NULL, err: File::NULL) ? "magick" : "convert"
  end

  # Strip MVG-breaking chars from user/DB-sourced text. Argv-form system() means
  # shell metachars are inert, but the MVG draw mini-language still parses
  # single quotes and backslashes inside `text 'string'`. Removing those is
  # safer than escaping and the visual loss is negligible for OG previews.
  def safe(str)
    str.to_s.gsub(/['"\\\r\n]/, "")
  end

  def top_bar
    ["-fill", "#e10600", "-draw", "rectangle 0,0 #{W},4"]
  end

  def branding
    ["-fill", DIM, "-pointsize", "18", "-font", "Helvetica-Bold",
     "-gravity", "NorthWest", "-draw", "text 40,28 'F1 ELO'"]
  end

  def round_info
    ["-fill", DIM, "-pointsize", "16", "-font", "Helvetica",
     "-gravity", "NorthEast", "-draw", "text 40,28 'Round #{@race.round.to_i} · #{@race.season.year.to_i}'"]
  end

  def circuit_title
    ["-fill", TXT, "-pointsize", "36", "-font", "Helvetica-Bold",
     "-gravity", "NorthWest", "-draw", "text 40,70 '#{safe(@race.circuit.name)}'"]
  end

  def author_line
    ["-fill", DIM, "-pointsize", "18", "-font", "Helvetica",
     "-gravity", "NorthWest", "-draw", "text 40,115 'Race Preview by #{safe(@user.display_name)}'"]
  end

  def divider
    ["-stroke", "#{DIM}44", "-strokewidth", "1",
     "-draw", "line 40,148 #{W - 40},148", "-stroke", "none"]
  end

  def driver_row(entry, driver, sd, i)
    pos = entry["position"].to_i
    col = i < 5 ? 0 : 1
    row = i < 5 ? i : i - 5
    x = col == 0 ? 40 : 620
    y = 170 + (row * 82)
    color = PODIUM_COLORS[pos] || TXT

    parts = [
      "-fill", color, "-pointsize", "28", "-font", "Helvetica-Bold",
      "-gravity", "NorthWest", "-draw", "text #{x},#{y} 'P#{pos}'",
      "-fill", TXT, "-pointsize", "24", "-font", "Helvetica-Bold",
      "-draw", "text #{x + 55},#{y + 2} '#{safe(driver.fullname)}'"
    ]
    if sd&.constructor
      parts.concat([
        "-fill", DIM, "-pointsize", "14", "-font", "Helvetica",
        "-draw", "text #{x + 55},#{y + 32} '#{safe(sd.constructor.name)}'"
      ])
    end
    parts
  end

  def footer
    ["-fill", "#{DIM}33", "-draw", "rectangle 0,#{H - 40} #{W},#{H}",
     "-fill", DIM, "-pointsize", "13", "-font", "Helvetica",
     "-gravity", "South", "-draw", "text 0,12 'f1elo.com'"]
  end
end
