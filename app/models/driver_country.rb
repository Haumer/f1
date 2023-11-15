class DriverCountry < ApplicationRecord
  belongs_to :driver
  belongs_to :country
end
