class FantasyStockSnapshot < ApplicationRecord
  belongs_to :fantasy_stock_portfolio
  belongs_to :race
end
