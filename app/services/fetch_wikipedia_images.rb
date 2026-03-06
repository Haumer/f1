class FetchWikipediaImages
  API_BASE = "https://en.wikipedia.org/w/api.php"

  def self.fetch_all
    new.fetch_all
  end

  def fetch_all
    updated = 0
    Driver.where.not(url: nil).find_each do |driver|
      next if driver.wikipedia_image_url.present?

      title = extract_title(driver.url)
      next unless title

      image_url = fetch_image_for(title)
      next unless image_url

      driver.update_column(:wikipedia_image_url, image_url)
      updated += 1
      Rails.logger.info("Wikipedia image for #{driver.fullname}: #{image_url}")
      sleep(0.1) # be nice to Wikipedia API
    end
    updated
  end

  private

  def extract_title(url)
    return nil if url.blank?
    URI.parse(url).path.split("/wiki/").last
  rescue URI::InvalidURIError
    nil
  end

  def fetch_image_for(title)
    uri = URI(API_BASE)
    uri.query = URI.encode_www_form(
      action: "query",
      titles: title,
      prop: "pageimages",
      pithumbsize: 400,
      format: "json"
    )

    response = Net::HTTP.get(uri)
    data = JSON.parse(response)
    pages = data.dig("query", "pages")
    return nil unless pages

    page = pages.values.first
    page&.dig("thumbnail", "source")
  rescue StandardError => e
    Rails.logger.warn("Wikipedia image fetch failed for #{title}: #{e.message}")
    nil
  end
end
