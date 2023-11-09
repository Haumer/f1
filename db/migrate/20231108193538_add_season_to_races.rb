class AddSeasonToRaces < ActiveRecord::Migration[7.0]
  def change
    add_reference :races, :season, null: true, foreign_key: true

    Race.all.pluck(:year).uniq.sort.each do |year|
      Season.create(year: year)
    end
    Season.all.each do |season|
      Race.where(year: season.year).each do |race|
        race.update(season: season)
      end
    end
  end
end
