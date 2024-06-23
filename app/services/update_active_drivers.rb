class UpdateActiveDrivers
    def self.update_season
        Driver.active.each { |driver| driver.update(active: false) }
        Season.last.season_drivers.each { |season_driver| season_driver.driver.update(active: true) }
    end
end