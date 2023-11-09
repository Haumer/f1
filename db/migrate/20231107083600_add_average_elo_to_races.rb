class AddAverageEloToRaces < ActiveRecord::Migration[7.0]
  def change
    add_column :races, :average_elo, :float
  end
end
