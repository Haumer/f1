class AddFantasyConcurrencyConstraints < ActiveRecord::Migration[7.0]
  def change
    # Prevent duplicate active roster entries for the same driver
    add_index :fantasy_roster_entries,
      [:fantasy_portfolio_id, :driver_id],
      unique: true,
      where: "active = true",
      name: "idx_unique_active_roster_entry"

    # Prevent duplicate active stock holdings for the same driver + direction
    add_index :fantasy_stock_holdings,
      [:fantasy_stock_portfolio_id, :driver_id, :direction],
      unique: true,
      where: "active = true",
      name: "idx_unique_active_stock_holding"
  end
end
