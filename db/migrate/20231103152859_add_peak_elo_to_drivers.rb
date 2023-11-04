class AddPeakEloToDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :peak_elo, :float
  end
end
