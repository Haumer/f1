class UpdateSeasonRaces
    def self.update
        Season.last.races_to_update.each do |race|
            UpdateRaceResult.new(race: race).update_all
        end
    end
end