class AddWikipediaImageUrlToDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :wikipedia_image_url, :string
  end
end
