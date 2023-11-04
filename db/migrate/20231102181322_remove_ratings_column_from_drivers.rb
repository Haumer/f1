class RemoveRatingsColumnFromDrivers < ActiveRecord::Migration[7.0]
  def change
    remove_column :drivers, :ratings
  end
end
