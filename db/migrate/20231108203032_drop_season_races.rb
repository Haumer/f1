class DropSeasonRaces < ActiveRecord::Migration[7.0]
  def change
    drop_table :season_races
  end
end
