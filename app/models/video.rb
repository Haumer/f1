class Video < ApplicationRecord
    belongs_to :video_media, polymorphic: true

    before_save :set_yt_id, :set_embed_html

    def set_yt_id
        return if url.blank?

        match_data = url.match(/v=(?<yt_id>[^&\s]+)/)
        self.yt_id = match_data[:yt_id] if match_data
    end

    def set_embed_html
        return if yt_id.blank?

        client = YtApi.new(video: self)
        self.embed_html = client.fetch_embed_html.embed_html
    end
end
