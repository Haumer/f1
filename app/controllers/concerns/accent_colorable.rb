module AccentColorable
  extend ActiveSupport::Concern

  DEFAULT_ACCENT = "#e10600"

  private

  def set_current_champion_accent
    standing = DriverStanding.where(season_end: true, position: 1)
                             .joins(race: :season)
                             .order("seasons.year DESC")
                             .first
    @page_accent = constructor_color_for_standing(standing) || DEFAULT_ACCENT
  end

  def set_season_champion_accent(season)
    standing = DriverStanding.where(season_end: true, position: 1)
                             .joins(:race)
                             .where(races: { season_id: season.id })
                             .first
    @page_accent = constructor_color_for_standing(standing) || DEFAULT_ACCENT
  end

  def set_race_winner_accent(race)
    winner = race.race_results.find_by(position_order: 1)
    @page_accent = constructor_color(winner&.constructor) || DEFAULT_ACCENT
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
