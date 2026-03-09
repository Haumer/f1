class AddCompositeIndexToFantasyStockTransactions < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :fantasy_stock_transactions,
              [:fantasy_stock_portfolio_id, :race_id, :kind],
              name: "idx_stock_txns_portfolio_race_kind",
              algorithm: :concurrently
  end
end
