class CreateVideos < ActiveRecord::Migration[7.0]
  def change
    create_table :videos do |t|
      t.string :yt_id
      t.string :embed_html
      t.references :video_media, polymorphic: true

      t.timestamps
    end
  end
end
