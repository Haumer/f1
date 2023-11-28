class AddSeasonEndToRaces < ActiveRecord::Migration[7.0]
  def change
    add_column :races, :season_end, :boolean
  end
end
