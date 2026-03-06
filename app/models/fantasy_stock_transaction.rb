class FantasyStockTransaction < ApplicationRecord
  belongs_to :fantasy_stock_portfolio
  belongs_to :driver, optional: true
  belongs_to :race, optional: true

  validates :kind, presence: true
  validates :amount, presence: true
end
