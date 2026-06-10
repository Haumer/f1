class AddAuditCompoundIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Profile portfolio queries (dividend totals, achievement checks) filter by
    # portfolio_id + kind without race_id; the existing 3-col index leads with
    # portfolio_id but race_id sits between them so it can't be used.
    add_index :fantasy_stock_transactions, [:fantasy_stock_portfolio_id, :kind],
              name: "idx_stock_txns_portfolio_kind", algorithm: :concurrently,
              if_not_exists: true

    # Constructor pages query season_drivers by (season, constructor) to list
    # the season's lineup; only single-col indexes existed.
    add_index :season_drivers, [:season_id, :constructor_id],
              name: "idx_season_drivers_season_constructor", algorithm: :concurrently,
              if_not_exists: true
  end
end
