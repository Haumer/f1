class AddActiveToDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :active, :boolean, default: false
  end
end
