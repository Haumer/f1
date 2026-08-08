class StockPriceSnapshot < ApplicationRecord
  belongs_to :driver
  belongs_to :race

  validates :elo, :price, presence: true
end
