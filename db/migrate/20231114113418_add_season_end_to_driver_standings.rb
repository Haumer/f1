class AddSeasonEndToDriverStandings < ActiveRecord::Migration[7.0]
  def change
    add_column :driver_standings, :season_end, :boolean
  end
end
