class Season < ApplicationRecord
    has_many :races
    has_many :season_drivers
    has_many :drivers, through: :season_drivers
    has_many :race_results, through: :drivers

    has_many :driver_standings, through: :drivers

    scope :sorted_by_year, -> { order(year: :desc) }

    validates :year, uniqueness: true

    def latest_driver_standings
        drivers.map do |driver|
            DriverStanding.find_by(race: latest_race, driver: driver)
        end.reject(&:blank?).sort_by { |driver_standing| -driver_standing.points }
    end

    def latest_race
        races.select { |race| race.driver_standings.present? }.sort_by { |race| race.round }.last
    end

    def next_race
        last_race = races.order(round: :desc).last
        return latest_race if latest_race == last_race

        races.find_by(round: latest_race.round + 1) 
    end

    def season_race_results
        races.sorted.map { |race| race.race_results }.flatten
    end

    def driver_last_season_race_result(driver)
        driver.races.where(year: self.year).sorted.last.race_results.find_by(driver: driver)
    end

    def first_race
        races.sorted.first
    end

    def last_race
        races.sorted.last
    end
end
