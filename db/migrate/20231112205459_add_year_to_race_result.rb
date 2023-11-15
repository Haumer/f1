class AddYearToRaceResult < ActiveRecord::Migration[7.0]
  def change
    add_column :race_results, :year, :integer
  end
end
