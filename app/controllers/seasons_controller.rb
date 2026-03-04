class SeasonsController < ApplicationController
    include StandingsData

    def index
        @seasons = Season.includes(:drivers, :races).sorted_by_year

        # Champion name per season
        @champions_by_season = DriverStanding.where(season_end: true, position: 1)
                                              .includes(:driver, race: :season)
                                              .index_by { |ds| ds.race.season_id }

        # Per-card champion constructor colors
        @champion_colors = champion_colors_by_season(@seasons)
    end

    def show
        @season = Season.find(params[:id])
        set_season_champion_accent(@season)
        @next_season = @season.next_season
        @previous_season = @season.previous_season
        @sorted_races = @season.races.order(round: :asc).includes(:circuit)
        race_ids = @sorted_races.pluck(:id)
        all_standings = DriverStanding.where(race_id: race_ids).includes(driver: [:countries, :season_drivers])
        @driver_driver_standings = all_standings.group_by(&:driver_id).values
        @driver_driver_standings = @driver_driver_standings.reject(&:blank?).sort_by do |driver_standing|
            -driver_standing.last.points
        end
        @standings_extras = build_standings_extras(@season)

        # Season Stats Bar
        @races_completed = Race.where(id: race_ids).joins(:race_results).distinct.count
        @total_races = @sorted_races.count
        latest_standings = @season.latest_driver_standings.sort_by(&:position)
        @leader_standing = latest_standings.first
        @most_wins_standing = latest_standings.max_by { |ds| ds.wins || 0 }
        elo_values = latest_standings.filter_map { |ds| @standings_extras[ds.driver_id]&.dig(:elo) }
        @avg_field_elo = elo_values.present? ? (elo_values.sum.to_f / elo_values.size).round : nil

        # Season Recap
        new_elo_col = Setting.elo_column(:new_elo)
        old_elo_col = Setting.elo_column(:old_elo)

        season_results = RaceResult.joins(:race)
                                    .where(races: { season_id: @season.id })
                                    .where.not(new_elo_col => nil, old_elo_col => nil)
                                    .includes(:driver, :constructor, race: :circuit)

        @season_elo_changes = season_results.group_by(&:driver_id).filter_map do |_driver_id, results|
            sorted = results.sort_by { |rr| rr.race.date }
            season_start = sorted.first.send(old_elo_col)
            season_end = sorted.last.send(new_elo_col)
            next unless season_start && season_end
            { driver: sorted.first.driver, change: (season_end - season_start).round,
              start_elo: season_start.round, end_elo: season_end.round }
        end.sort_by { |e| -e[:change] }

        @season_biggest_gainers = @season_elo_changes.first(5)
        @season_biggest_losers = @season_elo_changes.last(5).reverse
        @season_mvp = @season_elo_changes.first

        @biggest_race_gain = season_results.max_by { |rr| (rr.send(new_elo_col) || 0) - (rr.send(old_elo_col) || 0) }
        @biggest_race_drop = season_results.min_by { |rr| (rr.send(new_elo_col) || 0) - (rr.send(old_elo_col) || 0) }
    end
end
