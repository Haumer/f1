class AddMissingIndexes < ActiveRecord::Migration[7.0]
  def change
    add_index :constructors, :constructor_ref, unique: true
    add_index :constructors, :active
    add_index :constructors, :elo
    add_index :constructors, :elo_v2
    add_index :seasons, :year, unique: true
    add_index :drivers, :driver_ref, unique: true
    add_index :drivers, :active
    add_index :circuits, :circuit_ref
    add_index :race_results, :position_order
  end
end
