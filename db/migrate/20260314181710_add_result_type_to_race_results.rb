class AddResultTypeToRaceResults < ActiveRecord::Migration[7.0]
  def change
    add_column :race_results, :result_type, :string, default: "race", null: false

    remove_index :race_results, [:race_id, :driver_id], unique: true
    add_index :race_results, [:race_id, :driver_id, :result_type], unique: true, name: "index_race_results_on_race_driver_type"
  end
end
