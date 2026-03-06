class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
Ahoy.geocode = false

# Track bots or not
Ahoy.track_bots = false

# Better privacy — mask IPs
Ahoy.mask_ips = true

# Cookie duration
Ahoy.visit_duration = 30.minutes
