class UpdateActiveDrivers
    def self.update_season
        ActiveRecord::Base.transaction do
            Driver.where(active: true).update_all(active: false)

            # Active = has race results in the latest season with results
            latest_season = Season.sorted_by_year.joins(races: :race_results).distinct.first
            return unless latest_season

            active_ids = RaceResult.joins(:race)
                                   .where(races: { season_id: latest_season.id })
                                   .distinct
                                   .pluck(:driver_id)

            Driver.where(id: active_ids).update_all(active: true)
        end
    end
end
