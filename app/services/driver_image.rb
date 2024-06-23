class DriverImage
    def initialize(driver:)
        @driver = driver
    end

    def fetch
        page = Wikipedia.find(@driver.fullname)
        @driver.update(image_url: page.main_image_url)
    end
end