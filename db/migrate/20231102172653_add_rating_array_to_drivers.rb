class AddRatingArrayToDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :ratings, :integer, array: true, default: [1000]
  end
end
