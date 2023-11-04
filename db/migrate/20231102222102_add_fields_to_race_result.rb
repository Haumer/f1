class AddFieldsToRaceResult < ActiveRecord::Migration[7.0]
  def change
    add_column :race_results, :old_elo, :float
    add_column :race_results, :new_elo, :float
  end
end
