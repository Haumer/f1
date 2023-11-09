class CreateSeasonDrivers < ActiveRecord::Migration[7.0]
  def change
    create_table :season_drivers do |t|
      t.references :driver, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.references :constructor, null: false, foreign_key: true

      t.timestamps
    end
  end
end
