require "open3"

# Uses the same ImageMagick runtime as prediction previews. No browser, network,
# external images or user-specific state is needed to render this public card.
class RaceAnalysisOgGenerator
  def initialize(payload)
    @payload = payload
  end

  def generate
    args = ["-limit", "thread", "1", "-limit", "time", "15", "-size", "1200x630", "xc:#0a0a0f"]
    args += ["-fill", "#f0c850", "-draw", "rectangle 0,0 1200,5"]
    args += label(40, 38, "F1 ELO / RACE DEBRIEF", 17, "#f0c850")
    args += label(910, 38, "#{@payload[:year]} / ROUND #{@payload[:round]}", 17)
    args += label(40, 93, @payload[:circuit].to_s.truncate(53), 35, "#f1f1f5", bold: true)
    args += label(40, 135, "Elo + qualifying / Expected finish vs actual result", 21)
    args += column(40, "TOP 3", "Beat the estimate", @payload[:top], "#65dba0")
    args += column(620, "FLOP 3", "Below the estimate", @payload[:flop], "#ff9393")
    args += label(40, 551, "#{@payload[:assessed]}/#{@payload[:entrants]} entrants assessed · Classified finishers only · Experimental v1", 17)
    args += label(40, 584, "Gaps versus a model, not driver-skill scores. Full grid + methodology at f1elo.com", 16)
    args << "png:-"
    png, error, status = Open3.capture3(magick_bin, *args, binmode: true)
    raise "Race debrief image generation failed: #{error.to_s.first(200)}" unless status.success?

    png
  end

  private

  def magick_bin
    system("which", "magick", out: File::NULL, err: File::NULL) ? "magick" : "convert"
  end

  def column(x, title, subtitle, entries, color)
    args = ["-fill", "#12121a", "-draw", "roundrectangle #{x},176 #{x + 540},516 10,10"]
    args += label(x + 22, 202, title, 25, color, bold: true)
    args += label(x + 170, 211, subtitle, 16)
    if entries.empty?
      message = @payload[:assessed].zero? ? "No assessable classified finishes." : "No finishers on this side of the estimate."
      return args + label(x + 22, 310, message, 19)
    end

    entries.each_with_index do |entry, index|
      y = 257 + index * 82
      args += label(x + 22, y, "#{index + 1}", 22, color, bold: true)
      args += label(x + 56, y, entry[:name].truncate(23), 22, "#f1f1f5", bold: true)
      args += label(x + 421, y, format("%+.1f", entry[:difference]), 26, color, bold: true)
      args += label(x + 56, y + 32, "Expected P#{format('%.1f', entry[:expected])} / Finished P#{entry[:finish]}", 16)
      args += label(x + 421, y + 32, "places", 14)
    end
    args
  end

  def label(x, y, text, size, color = "#aaaabb", bold: false)
    # Argv avoids shell evaluation; this also protects ImageMagick's MVG text
    # mini-language and disables percent-expression expansion in DB values.
    safe = text.to_s.gsub(/[\p{Cntrl}'"\\%]/, "")
    ["-fill", color, "-font", bold ? "Helvetica-Bold" : "Helvetica", "-pointsize", size.to_s,
     "-gravity", "NorthWest", "-draw", "text #{x},#{y} '#{safe}'"]
  end
end
