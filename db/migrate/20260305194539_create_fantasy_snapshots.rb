class CreateFantasySnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :fantasy_snapshots do |t|
      t.references :fantasy_portfolio, null: false, foreign_key: true
      t.references :race, null: false, foreign_key: true
      t.float :value
      t.float :cash
      t.integer :rank

      t.timestamps
    end

    add_index :fantasy_snapshots, [:fantasy_portfolio_id, :race_id], unique: true
  end
end
