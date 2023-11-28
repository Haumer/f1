class YtApi
    attr_reader :yt_client, :embed_html

    def initialize(video:)
        @video = video
        Yt.configure do |config|
            config.api_key = ENV["YOUTUBE_API_KEY"]
            config.log_level = :debug
          end
        @yt_client = Yt::Video.new id: @video.yt_id
    end

    def has_embed_html?
        @video.embed_html.present?
    end

    def fetch_embed_html
        @embed_html =  @yt_client.embed_html
        self
    end
end
