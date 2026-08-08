module DisplayElo
  extend ActiveSupport::Concern

  def display_elo
    elo_v2
  end

  def display_peak_elo
    peak_elo_v2
  end
end
