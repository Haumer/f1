class Video < ApplicationRecord
    belongs_to :video_media, polymorphic: true

    before_save :set_yt_id, :set_embed_html

    def set_yt_id
        match_data = url.match(/v=(?<yt_id>\w*)&/)
        self.yt_id = match_data[:yt_id]
    end

    def set_embed_html
        client = YtApi.new(video: self)
        self.embed_html = client.fetch_embed_html.embed_html
    end
end
