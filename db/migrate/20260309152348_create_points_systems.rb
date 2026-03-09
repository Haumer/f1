class CreatePointsSystems < ActiveRecord::Migration[7.0]
  def change
    create_table :points_systems do |t|
      t.references :season, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :race_points
      t.jsonb :sprint_points
      t.integer :fastest_lap_eligible
      t.integer :fastest_lap_point
      t.integer :positions_scoring
      t.integer :sprint_positions_scoring
      t.string :notes

      t.timestamps
    end
  end
end
