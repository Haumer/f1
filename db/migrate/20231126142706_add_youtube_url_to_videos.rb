class AddYoutubeUrlToVideos < ActiveRecord::Migration[7.0]
  def change
    add_column :videos, :url, :string
  end
end
