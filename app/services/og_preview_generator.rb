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

    draws = []
    draws << top_bar
    draws << branding
    draws << round_info
    draws << circuit_title
    draws << author_line
    draws << divider

    results.each_with_index do |entry, i|
      driver = drivers[entry["driver_id"]]
      next unless driver
      draws.concat(driver_row(entry, driver, sd_index[driver.id], i))
    end

    draws << footer

    output = Tempfile.new(["og-preview", ".png"])
    bin = system("which magick > /dev/null 2>&1") ? "magick" : "convert"
    cmd = "#{bin} -size #{W}x#{H} xc:'#1a1a2e' #{draws.join(' ')} png:#{output.path}"
    system(cmd)
    output
  end

  private

  def esc(str)
    str.gsub("'", "'\\\\''")
  end

  def top_bar
    "-fill '#e10600' -draw 'rectangle 0,0 #{W},4'"
  end

  def branding
    "-fill '#{DIM}' -pointsize 18 -font Helvetica-Bold -gravity NorthWest -draw \"text 40,28 'F1 ELO'\""
  end

  def round_info
    "-fill '#{DIM}' -pointsize 16 -font Helvetica -gravity NorthEast -draw \"text 40,28 'Round #{@race.round} · #{@race.season.year}'\""
  end

  def circuit_title
    "-fill '#{TXT}' -pointsize 36 -font Helvetica-Bold -gravity NorthWest -draw \"text 40,70 '#{esc(@race.circuit.name)}'\""
  end

  def author_line
    "-fill '#{DIM}' -pointsize 18 -font Helvetica -gravity NorthWest -draw \"text 40,115 'Race Preview by #{esc(@user.display_name)}'\""
  end

  def divider
    "-stroke '#{DIM}44' -strokewidth 1 -draw 'line 40,148 #{W - 40},148' -stroke none"
  end

  def driver_row(entry, driver, sd, i)
    pos = entry["position"]
    col = i < 5 ? 0 : 1
    row = i < 5 ? i : i - 5
    x = col == 0 ? 40 : 620
    y = 170 + (row * 82)
    color = PODIUM_COLORS[pos] || TXT

    parts = []
    parts << "-fill '#{color}' -pointsize 28 -font Helvetica-Bold -gravity NorthWest -draw \"text #{x},#{y} 'P#{pos}'\""
    parts << "-fill '#{TXT}' -pointsize 24 -font Helvetica-Bold -draw \"text #{x + 55},#{y + 2} '#{esc(driver.fullname)}'\""
    if sd&.constructor
      parts << "-fill '#{DIM}' -pointsize 14 -font Helvetica -draw \"text #{x + 55},#{y + 32} '#{esc(sd.constructor.name)}'\""
    end
    parts
  end

  def footer
    "-fill '#{DIM}33' -draw 'rectangle 0,#{H - 40} #{W},#{H}' -fill '#{DIM}' -pointsize 13 -font Helvetica -gravity South -draw \"text 0,12 'f1elo.com'\""
  end
end
