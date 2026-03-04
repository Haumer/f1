class Season < ApplicationRecord
    has_many :races
    has_many :season_drivers
    has_many :drivers, through: :season_drivers
    has_many :race_results, through: :drivers
    has_many :videos, as: :video_media

    has_many :driver_standings, through: :drivers

    scope :sorted_by_year, -> { order(year: :desc) }

    validates :year, uniqueness: true

    def latest_driver_standings
        race = latest_race
        return [] unless race

        DriverStanding.where(race: race)
                      .includes(driver: [:countries, :season_drivers])
                      .order(points: :desc)
                      .to_a
    end

    def latest_driver_standings_for(driver)
        DriverStanding.find_by(race: latest_race, driver: driver)
    end

    def latest_race
        races.joins(:driver_standings).distinct.order(round: :desc).first
    end

    def next_season
        Season.find_by(year: "#{self.year.to_i + 1}")
    end

    def previous_season
        Season.find_by(year: "#{self.year.to_i - 1}")
    end

    def next_race
        return nil if latest_race.nil?

        first_race = races.order(round: :asc).first
        return latest_race if latest_race == first_race

        races.find_by(round: latest_race.round + 1)
    end

    def season_race_results
        RaceResult.joins(:race).where(races: { season_id: id }).order('races.date ASC')
    end

    def first_race
        races.sorted.first
    end

    def last_race
        races.find_by(season_end: true)
    end

    def races_to_update
        races.select do |race|
            !race.race_results.present? && race.date <= Date.today
        end
    end
end
