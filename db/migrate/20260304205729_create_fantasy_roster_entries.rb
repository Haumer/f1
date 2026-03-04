class CreateFantasyRosterEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :fantasy_roster_entries do |t|
      t.references :fantasy_portfolio, null: false, foreign_key: true
      t.references :driver, null: false, foreign_key: true
      t.float :bought_at_elo, null: false
      t.references :bought_race, foreign_key: { to_table: :races }
      t.float :sold_at_elo
      t.references :sold_race, foreign_key: { to_table: :races }
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :fantasy_roster_entries, [:fantasy_portfolio_id, :active]
  end
end
