class AddImageUrlToDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :image_url, :string
  end
end
