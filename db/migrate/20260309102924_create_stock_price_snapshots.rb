class CreateStockPriceSnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :stock_price_snapshots do |t|
      t.references :driver, null: false, foreign_key: true
      t.references :race, null: false, foreign_key: true
      t.decimal :elo, precision: 10, scale: 2, null: false
      t.integer :net_demand, default: 0, null: false
      t.decimal :price, precision: 10, scale: 4, null: false
      t.timestamps
    end

    add_index :stock_price_snapshots, [:driver_id, :race_id], unique: true
  end
end
