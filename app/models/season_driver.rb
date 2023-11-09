class SeasonDriver < ApplicationRecord
  belongs_to :driver
  belongs_to :season
  belongs_to :constructor
end
