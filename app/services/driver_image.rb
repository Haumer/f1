class DriverImage
    def initialize(driver:)
        @driver = driver
    end

    def fetch
        page = Wikipedia.find(@driver.fullname)
        @driver.update(image_url: page.main_image_url)
    rescue StandardError => e
        Rails.logger.error("Failed to fetch image for #{@driver.fullname}: #{e.message}")
        nil
    end
end
