class Rack::Attack
  ### Throttle login attempts ###
  # 5 attempts per 20 seconds per IP
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  # 5 attempts per 20 seconds per email
  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email")&.to_s&.downcase&.strip
    end
  end

  ### Throttle signup ###
  # 3 signups per minute per IP
  throttle("signups/ip", limit: 3, period: 60.seconds) do |req|
    req.ip if req.path == "/users" && req.post?
  end

  ### Throttle password reset ###
  # 3 resets per minute per IP
  throttle("password_resets/ip", limit: 3, period: 60.seconds) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  ### Throttle username availability checks ###
  # 10 per 10 seconds per IP
  throttle("username_check/ip", limit: 10, period: 10.seconds) do |req|
    req.ip if req.path == "/users/username_available"
  end

  ### Throttle driver search ###
  # 15 per 10 seconds per IP
  throttle("search/ip", limit: 15, period: 10.seconds) do |req|
    req.ip if req.path == "/drivers/search"
  end

  ### General request throttle ###
  # 60 requests per minute per IP (prevents aggressive scraping)
  throttle("requests/ip", limit: 60, period: 60.seconds) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  ### Fantasy trade throttle ###
  # 10 trade actions per minute per IP
  throttle("fantasy_trades/ip", limit: 10, period: 60.seconds) do |req|
    if req.post? && (req.path.match?(%r{/fantasy/\d+/(buy|sell|buy_multiple|buy_team)}) ||
                     req.path.match?(%r{/stocks/\d+/(buy|sell|short_open|short_close|buy_batch)}))
      req.ip
    end
  end

  ### Custom response ###
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    headers = {
      "Content-Type" => "text/plain",
      "Retry-After" => (match_data[:period] - (now % match_data[:period])).to_s
    }

    [429, headers, ["Rate limit exceeded. Try again later.\n"]]
  end
end
