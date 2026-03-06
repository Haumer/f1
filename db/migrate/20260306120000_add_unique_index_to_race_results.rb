class AddUniqueIndexToRaceResults < ActiveRecord::Migration[7.0]
  def up
    # Remove duplicates, keeping the record with the lowest id
    execute <<~SQL
      DELETE FROM race_results
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM race_results
        GROUP BY race_id, driver_id
      )
    SQL

    remove_index :race_results, [:driver_id, :race_id]
    remove_index :race_results, [:race_id, :driver_id]
    add_index :race_results, [:race_id, :driver_id], unique: true
  end

  def down
    remove_index :race_results, [:race_id, :driver_id]
    add_index :race_results, [:driver_id, :race_id]
    add_index :race_results, [:race_id, :driver_id]
  end
end
