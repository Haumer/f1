class RemoveEloV1Columns < ActiveRecord::Migration[7.0]
  def up
    # Remove V1 Elo columns from drivers (V2 columns elo_v2/peak_elo_v2 are now canonical)
    remove_column :drivers, :elo
    remove_column :drivers, :peak_elo

    # Remove V1 Elo columns from constructors
    remove_column :constructors, :elo
    remove_column :constructors, :peak_elo

    # Remove V1 Elo columns from race_results
    remove_column :race_results, :old_elo
    remove_column :race_results, :new_elo
  end

  def down
    add_column :drivers, :elo, :float
    add_column :drivers, :peak_elo, :float
    add_column :constructors, :elo, :float
    add_column :constructors, :peak_elo, :float
    add_column :race_results, :old_elo, :float
    add_column :race_results, :new_elo, :float
  end
end
