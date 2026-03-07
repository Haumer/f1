module AccentColorable
  extend ActiveSupport::Concern

  DEFAULT_ACCENT = "#e10600"

  private

  def set_current_champion_accent
    @page_accent = Rails.cache.fetch("current_champion_accent", expires_in: 1.day) do
      override = Setting.get("accent_constructor_override")
      if override.present?
        Constructor::COLORS[override.to_sym] || DEFAULT_ACCENT
      else
        standing = DriverStanding.where(season_end: true, position: 1)
                                 .joins(race: :season)
                                 .order("seasons.year DESC")
                                 .first
        constructor_color_for_standing(standing) || DEFAULT_ACCENT
      end
    end
    sanitize_page_accent!
  end

  def set_season_champion_accent(season)
    standing = DriverStanding.where(season_end: true, position: 1)
                             .joins(:race)
                             .where(races: { season_id: season.id })
                             .first
    @page_accent = constructor_color_for_standing(standing) || DEFAULT_ACCENT
    sanitize_page_accent!
  end

  def set_race_winner_accent(race)
    winner = race.race_results.find_by(position_order: 1)
    if winner
      @page_accent = constructor_color(winner.constructor) || DEFAULT_ACCENT
    else
      # No race result yet — use reigning champion's constructor color
      standing = DriverStanding.where(season_end: true, position: 1)
                               .joins(race: :season)
                               .order("seasons.year DESC")
                               .first
      @page_accent = constructor_color_for_standing(standing) || DEFAULT_ACCENT
    end
    sanitize_page_accent!
  end

  def set_latest_race_winner_accent
    @page_accent = Rails.cache.fetch("latest_race_winner_accent", expires_in: 1.hour) do
      latest = Race.joins(:race_results).order(date: :desc).first
      winner = latest&.race_results&.find_by(position_order: 1)
      constructor_color(winner&.constructor) || DEFAULT_ACCENT
    end
    sanitize_page_accent!
  end

  def set_constructor_accent(constructor)
    @page_accent = constructor_color(constructor) || DEFAULT_ACCENT
    sanitize_page_accent!
  end

  def set_driver_accent(driver)
    sd = driver.season_drivers.includes(:constructor).joins(:season).order("seasons.year DESC").first
    @page_accent = constructor_color(sd&.constructor) || DEFAULT_ACCENT
    sanitize_page_accent!
  end

  def set_circuit_accent(circuit)
    latest_race = circuit.races.joins(:race_results).order(date: :desc).first
    winner = latest_race&.race_results&.find_by(position_order: 1)
    @page_accent = constructor_color(winner&.constructor) || DEFAULT_ACCENT
    sanitize_page_accent!
  end

  def constructor_color_for_standing(standing)
    return nil unless standing

    result = RaceResult.find_by(race_id: standing.race_id, driver_id: standing.driver_id)
    constructor_color(result&.constructor)
  end

  def constructor_color(constructor)
    return nil unless constructor

    Constructor::COLORS[constructor.constructor_ref&.to_sym]
  end

  def sanitize_page_accent!
    @page_accent = nil unless @page_accent&.match?(/\A#[0-9a-fA-F]{3,8}\z/)
  end

  def champion_colors_by_season(seasons)
    standings = DriverStanding.where(season_end: true, position: 1)
                              .includes(race: { race_results: :constructor })
                              .joins(:race)
                              .where(races: { season_id: seasons.map(&:id) })

    standings.each_with_object({}) do |standing, hash|
      result = standing.race.race_results.find { |rr| rr.driver_id == standing.driver_id }
      color = constructor_color(result&.constructor)
      hash[standing.race.season_id] = color if color
    end
  end
end
