class AddActiveToSeasonDriver < ActiveRecord::Migration[7.0]
  def change
    add_column :season_drivers, :active, :boolean
    add_column :season_drivers, :standin, :boolean
  end
end
