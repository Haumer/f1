class CreateFantasyStockTables < ActiveRecord::Migration[7.0]
  def change
    create_table :fantasy_stock_portfolios do |t|
      t.references :user, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.float :cash, null: false, default: 0.0
      t.float :starting_capital, null: false
      t.timestamps
      t.index [:user_id, :season_id], unique: true
    end

    create_table :fantasy_stock_holdings do |t|
      t.references :fantasy_stock_portfolio, null: false, foreign_key: true, index: true
      t.references :driver, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.string :direction, null: false # "long" or "short"
      t.float :entry_price, null: false
      t.float :collateral, default: 0.0 # locked cash for shorts
      t.references :opened_race, null: false, foreign_key: { to_table: :races }
      t.references :closed_race, foreign_key: { to_table: :races }
      t.boolean :active, default: true
      t.timestamps
      t.index [:fantasy_stock_portfolio_id, :driver_id, :direction, :active],
              name: "idx_stock_holdings_portfolio_driver_dir_active"
    end

    create_table :fantasy_stock_transactions do |t|
      t.references :fantasy_stock_portfolio, null: false, foreign_key: true, index: true
      t.references :driver, foreign_key: true
      t.references :race, foreign_key: true
      t.string :kind, null: false # buy, sell, short_open, short_close, dividend, borrow_fee, liquidation
      t.integer :quantity
      t.float :price
      t.float :amount, null: false
      t.string :note
      t.timestamps
    end

    create_table :fantasy_stock_snapshots do |t|
      t.references :fantasy_stock_portfolio, null: false, foreign_key: true, index: true
      t.references :race, null: false, foreign_key: true
      t.float :value
      t.float :cash
      t.integer :rank
      t.timestamps
      t.index [:fantasy_stock_portfolio_id, :race_id],
              name: "idx_stock_snapshots_portfolio_race", unique: true
    end
  end
end
