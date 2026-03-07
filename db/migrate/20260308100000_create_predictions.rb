class CreatePredictions < ActiveRecord::Migration[7.0]
  def change
    create_table :predictions do |t|
      t.references :race, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :predicted_results, default: []   # [{driver_id:, position:, grid:}]
      t.jsonb :elo_changes, default: {}         # {driver_id => {old_elo:, new_elo:, diff:}}
      t.text :analysis
      t.jsonb :fantasy_picks, default: {}       # {roster:[], longs:[], shorts:[]}
      t.jsonb :sources, default: []
      t.datetime :generated_at

      t.timestamps
    end

    add_index :predictions, [:race_id, :user_id], unique: true
  end
end
