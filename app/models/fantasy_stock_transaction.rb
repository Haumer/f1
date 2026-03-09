class FantasyStockTransaction < ApplicationRecord
  belongs_to :fantasy_stock_portfolio
  belongs_to :driver, optional: true
  belongs_to :race, optional: true

  KINDS = %w[buy sell short_open short_close dividend borrow_fee liquidation starting_capital].freeze
  validates :kind, inclusion: { in: KINDS }
  validates :amount, presence: true
end
