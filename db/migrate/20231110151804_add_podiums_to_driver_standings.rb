class AddPodiumsToDriverStandings < ActiveRecord::Migration[7.0]
  def change
    add_column :driver_standings, :podiums, :integer
    add_column :driver_standings, :second_places, :integer
    add_column :driver_standings, :third_places, :integer
  end
end
