class FantasyStockSnapshot < ApplicationRecord
  belongs_to :fantasy_stock_portfolio
  belongs_to :race

  validates :value, :cash, presence: true
end
