class AddConstructorEloV2Fields < ActiveRecord::Migration[7.0]
  def change
    add_column :constructors, :elo_v2, :float
    add_column :constructors, :peak_elo_v2, :float

    add_column :race_results, :old_constructor_elo_v2, :float
    add_column :race_results, :new_constructor_elo_v2, :float
  end
end
