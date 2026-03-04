class AddEloToConstructors < ActiveRecord::Migration[7.0]
  def change
    add_column :constructors, :elo, :float
    add_column :constructors, :peak_elo, :float
  end
end
