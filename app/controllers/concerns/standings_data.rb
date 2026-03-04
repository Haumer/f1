module StandingsData
  extend ActiveSupport::Concern

  private

  # Pre-computes elo and constructor data for the standings table partial.
  # Returns { driver_id => { elo: ..., elo_diff: ..., constructors: [...] } }
  def build_standings_extras(season)
    race_ids = season.races.pluck(:id)
    driver_ids = season.season_drivers.pluck(:driver_id).uniq

    elo_col = Setting.elo_column(:new_elo)
    old_elo_col = Setting.elo_column(:old_elo)

    # Batch-load all season race results for these drivers
    all_results = RaceResult.where(race_id: race_ids, driver_id: driver_ids)
                            .joins(:race)
                            .order('races.date ASC')
                            .select(:driver_id, old_elo_col, elo_col)
                            .group_by(&:driver_id)

    # Batch-load constructors per driver for this season
    season_drivers = SeasonDriver.where(season: season, driver_id: driver_ids)
                                 .includes(:constructor)
                                 .order(:id)
                                 .group_by(&:driver_id)

    extras = {}
    driver_ids.each do |did|
      results = all_results[did] || []
      constructors = (season_drivers[did] || []).map(&:constructor).uniq(&:id)

      elo = results.last&.send(elo_col)&.round
      elo_diff = if results.present? && results.last.send(elo_col) && results.first.send(old_elo_col)
                   results.last.send(elo_col).round - results.first.send(old_elo_col).round
                 end

      extras[did] = { elo: elo, elo_diff: elo_diff, constructors: constructors }
    end
    extras
  end
end
