class FetchDriverHeadshots
  OPENF1_URL = "https://api.openf1.org/v1/drivers?session_key=latest"

  def self.fetch_all
    new.fetch_all
  end

  def fetch_all
    response = Net::HTTP.get(URI(OPENF1_URL))
    openf1_drivers = JSON.parse(response)

    updated = 0

    openf1_drivers.each do |of1|
      headshot_url = of1["headshot_url"]
      next if headshot_url.blank?

      full_name = of1["full_name"]
      next if full_name.blank?

      driver = find_driver(full_name, of1)
      next unless driver

      driver.update!(image_url: headshot_url)
      updated += 1
      Rails.logger.info("Updated headshot for #{driver.fullname}")
    end

    updated
  end

  private

  def find_driver(full_name, of1)
    parts = full_name.strip.split(/\s+/)
    forename = parts.first
    surname = parts.last

    # Try exact match first
    driver = Driver.find_by("LOWER(forename) = ? AND LOWER(surname) = ?", forename.downcase, surname.downcase)
    return driver if driver

    # Try by driver code
    if of1["name_acronym"].present?
      driver = Driver.find_by("UPPER(code) = ?", of1["name_acronym"].upcase)
      return driver if driver
    end

    Rails.logger.warn("No driver match for OpenF1: #{full_name} (#{of1['name_acronym']})")
    nil
  end
end
