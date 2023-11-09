class Season < ApplicationRecord
    has_many :races
    has_many :season_drivers
    has_many :drivers, through: :season_drivers
end
