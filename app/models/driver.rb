class Driver < ApplicationRecord
    has_many :race_results
    has_many :driver_ratings
    has_many :constructors, through: :race_results

    scope :active, -> { where(active: true) }
    scope :elite, -> { where(skill: 'elite') }

    def peak_elo_race_result
        self.race_results.order(new_elo: :desc).first
    end

    def lowest_elo
        self.race_results.pluck(:new_elo).min
    end
end
