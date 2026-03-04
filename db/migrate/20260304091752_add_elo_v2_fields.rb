class AddEloV2Fields < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :elo_v2, :float
    add_column :drivers, :peak_elo_v2, :float

    add_column :race_results, :old_elo_v2, :float
    add_column :race_results, :new_elo_v2, :float
  end
end
