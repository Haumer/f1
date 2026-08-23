# Rebuilds app/assets/geo/world.geo.json — the country outlines behind the
# circuit calendar map. Only needs re-running if the borders themselves need
# updating; the output is committed.
namespace :geo do
  SOURCE_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/" \
               "master/geojson/ne_110m_admin_0_countries.geojson".freeze
  PRECISION = 2 # decimal places ≈ 1.1 km, well under a pixel at world zoom

  desc "Rebuild the simplified world GeoJSON used by the circuit map"
  task :world do
    require "json"
    require "open-uri"

    puts "Fetching #{SOURCE_URL}"
    raw = JSON.parse(URI.parse(SOURCE_URL).open(read_timeout: 60).read)
    original = raw.to_json.bytesize

    # Rounding leaves runs of identical points behind; drop them, and discard any
    # ring that no longer has enough points to close into a polygon.
    thin = lambda do |ring|
      out = ring.map { |x, y| [x.round(PRECISION), y.round(PRECISION)] }
                .chunk_while { |a, b| a == b }.map(&:first)
      next nil if out.size < 4
      out << out.first if out.first != out.last
      out
    end

    simplify = lambda do |geom|
      case geom["type"]
      when "Polygon"
        rings = geom["coordinates"].filter_map(&thin)
        rings.any? ? { "type" => "Polygon", "coordinates" => rings } : nil
      when "MultiPolygon"
        polys = geom["coordinates"].filter_map { |poly| poly.filter_map(&thin).presence }
        polys.any? ? { "type" => "MultiPolygon", "coordinates" => polys } : nil
      end
    end

    features = raw["features"].filter_map do |f|
      name = f.dig("properties", "NAME") || f.dig("properties", "ADMIN")
      # Antarctica is the largest polygon in the file and has never hosted a GP.
      next if name == "Antarctica"

      geometry = simplify.call(f["geometry"])
      next unless geometry

      { "type" => "Feature", "properties" => { "name" => name }, "geometry" => geometry }
    end

    path = Rails.root.join("app/assets/geo/world.geo.json")
    path.write({ "type" => "FeatureCollection", "features" => features }.to_json)

    puts "#{features.size} countries · #{original} b -> #{path.size} b " \
         "(#{(path.size * 100.0 / original).round(1)}%)"
    puts "Wrote #{path}"
  end
end
