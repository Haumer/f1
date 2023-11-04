class AddDriverSkillAndTenureToDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :skill, :string
    add_column :drivers, :number_of_races, :string
  end
end
