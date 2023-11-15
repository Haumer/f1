class RestElo

    def self.hard_reset
        puts "confirm with 'y'"
        confirm = gets.chomp
        if confirm.downcase == 'y'
            puts "resetting"
            Driver.all.each do |driver|
                driver.update(peak_elo: 0, elo: 1000)
            end
            Race.sorted.each do |race|
                EloRating::Race.new(race: race).update_driver_ratings
            end
        else
            puts "not confirmed"
        end
    end
end