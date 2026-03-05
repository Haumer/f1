class FantasySnapshot < ApplicationRecord
  belongs_to :fantasy_portfolio
  belongs_to :race

  validates :fantasy_portfolio_id, uniqueness: { scope: :race_id }
  validates :value, :cash, presence: true
end
