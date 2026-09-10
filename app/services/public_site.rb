require "uri"

module PublicSite
  DEFAULT_HOST = "f1elo.com"

  module_function

  def base_url(host: ENV.fetch("APP_HOST", DEFAULT_HOST))
    configured_host = host.to_s.strip.delete_suffix("/")
    configured_host = DEFAULT_HOST if configured_host.empty?
    return configured_host if configured_host.match?(%r{\Ahttps?://})

    "https://#{configured_host}"
  end

  def url(path = "/", host: ENV.fetch("APP_HOST", DEFAULT_HOST))
    normalized_path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
    "#{base_url(host: host)}#{normalized_path}"
  end

  def host(configured_host: ENV.fetch("APP_HOST", DEFAULT_HOST))
    URI.parse(base_url(host: configured_host)).host
  end
end
