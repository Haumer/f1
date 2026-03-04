class FantasyTransaction < ApplicationRecord
  belongs_to :fantasy_portfolio
  belongs_to :driver, optional: true
  belongs_to :race, optional: true

  KINDS = %w[buy sell login_bonus interaction_bonus].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :amount, presence: true
end
