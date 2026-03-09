class StockPriceSnapshot < ApplicationRecord
  belongs_to :driver
  belongs_to :race
end
