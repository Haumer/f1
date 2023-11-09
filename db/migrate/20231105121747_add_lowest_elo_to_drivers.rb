class AddLowestEloToDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :lowest_elo, :float
  end
end
