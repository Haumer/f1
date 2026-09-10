class Ahoy::Store < Ahoy::DatabaseStore
  # Aggregate traffic is useful; attaching browsing history to an account is
  # not necessary for it. This also keeps new analytics data independent from
  # the authentication lifecycle.
  def authenticate(_data)
  end
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
Ahoy.geocode = false

# Track bots or not
Ahoy.track_bots = false

# Better privacy — mask IPs
Ahoy.mask_ips = true

# Use Ahoy's anonymity sets instead of persistent visitor cookies. Existing
# Ahoy cookies are removed automatically when this mode is enabled.
Ahoy.cookies = :none

# Cookie duration
Ahoy.visit_duration = 30.minutes
