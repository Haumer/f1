class AddRosterSlotsToFantasyPortfolios < ActiveRecord::Migration[7.0]
  def change
    add_column :fantasy_portfolios, :roster_slots, :integer, default: 2, null: false
  end
end
