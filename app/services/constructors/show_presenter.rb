module Constructors
  class ShowPresenter
    def initialize(constructor:, current_user:, current_season:)
      @constructor = constructor
      @current_user = current_user
      @current_season = current_season
      @results = @constructor.race_results.to_a
    end

    def call
      {
        constructor: @constructor,
        total_races: total_races,
        race_wins: race_wins,
        podiums: podiums,
        win_rate: win_rate,
        championship_standings: championship_standings,
        championship_wins: championship_standings.size,
        championship_years: championship_years,
        best_season: best_season,
        top_drivers: top_drivers,
        most_winning_driver: top_drivers.first,
        supporter_count: supporter_count,
        user_supports_any: user_supports_any,
        user_supports_this: user_supports_this,
        fans: fans,
        current_drivers: current_drivers,
        recent_form: recent_form,
        recent_results: recent_results,
        roster_by_season: roster_by_season,
        recent_roster: roster_by_season.first(5),
        historical_roster: roster_by_season.drop(5)
      }
    end

    private

    def total_races
      @total_races ||= @results.map(&:race_id).uniq.size
    end

    def race_wins
      @race_wins ||= @results.count { |rr| rr.position_order == 1 }
    end

    def podiums
      @results.count { |rr| rr.position_order && rr.position_order <= 3 }
    end

    def win_rate
      total_races.positive? ? (race_wins.to_f / total_races * 100).round(1) : 0
    end

    def championship_standings
      @championship_standings ||= @constructor.constructor_standings
        .where(race_id: season_end_race_ids, position: 1)
        .includes(race: :season)
    end

    def championship_years
      championship_standings.map { |cs| cs.race.season.year }.sort
    end

    def season_end_race_ids
      @season_end_race_ids ||= Race.where(season_end: true).pluck(:id)
    end

    def best_season
      wins_by_year = @results.select { |rr| rr.position_order == 1 }.group_by { |rr| rr.race.year }
      return nil if wins_by_year.empty?

      best_year, best_wins = wins_by_year.max_by { |y, rrs| [rrs.size, y.to_i] }
      { year: best_year, wins: best_wins.size }
    end

    def top_drivers
      @top_drivers ||= begin
        wins_by_driver = @results.select { |rr| rr.position_order == 1 }.group_by(&:driver_id)
        podiums_by_driver = @results.select { |rr| rr.position_order && rr.position_order <= 3 }.group_by(&:driver_id)
        races_by_driver = @results.group_by(&:driver_id)

        driver_ids = races_by_driver.keys
        drivers_index = Driver.where(id: driver_ids).includes(:countries).index_by(&:id)

        driver_ids.filter_map do |did|
          driver = drivers_index[did]
          next unless driver
          {
            driver: driver,
            wins: wins_by_driver[did]&.size || 0,
            podiums: podiums_by_driver[did]&.size || 0,
            races: races_by_driver[did]&.map(&:race_id)&.uniq&.size || 0
          }
        end.sort_by { |d| [-d[:wins], -d[:podiums], -d[:races]] }
      end
    end

    def supporter_count
      ConstructorSupport.where(constructor: @constructor, active: true).count
    end

    def user_supports_any
      @current_user && ConstructorSupport.current_for(@current_user, @current_season).present?
    end

    def user_supports_this
      @current_user && ConstructorSupport.exists?(
        user: @current_user,
        constructor: @constructor,
        season: @current_season,
        active: true
      )
    end

    def fans
      User.joins(:constructor_supports)
          .where(constructor_supports: { constructor: @constructor, active: true })
          .distinct.to_a
    end

    def current_drivers
      return [] unless @constructor.active
      @current_drivers ||= SeasonDriver
        .where(season: @current_season, constructor: @constructor, standin: [false, nil])
        .includes(driver: :countries).map(&:driver).uniq
    end

    def recent_form
      return {} if current_drivers.empty?

      driver_ids = current_drivers.map(&:id)
      RaceResult.where(driver_id: driver_ids)
                .joins(:race).order("races.date DESC")
                .includes(race: :circuit)
                .limit(driver_ids.size * 5)
                .group_by(&:driver_id)
                .transform_values { |rrs| rrs.first(5) }
    end

    def recent_results
      recent_race_ids = @results.map(&:race).uniq.sort_by(&:date).last(5).map(&:id)
      @results.select { |rr| recent_race_ids.include?(rr.race_id) }
              .sort_by { |rr| [-rr.race.date.to_time.to_i, rr.position_order || 999] }
    end

    def roster_by_season
      @roster_by_season ||= @constructor.season_drivers
        .includes(:driver, :season)
        .group_by(&:season)
        .sort_by { |season, _| -season.year.to_i }
    end
  end
end
