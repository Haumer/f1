class CreateRaceResults < ActiveRecord::Migration[7.0]
  def change
    create_table :race_results do |t|
      t.integer :kaggle_id
      t.references :race, null: false, foreign_key: true
      t.references :constructor, null: false, foreign_key: true
      t.references :driver, null: false, foreign_key: true
      t.integer :number
      t.integer :grid
      t.integer :position
      t.integer :points
      t.integer :position_order
      t.string :time
      t.string :milliseconds
      t.integer :fastest_lap
      t.integer :laps
      t.string :fastest_lap_time
      t.float :fastest_lap_speed
      t.references :status, null: false, foreign_key: true

      t.timestamps
    end
  end
end
