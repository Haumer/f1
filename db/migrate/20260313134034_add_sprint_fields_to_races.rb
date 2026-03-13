class AddSprintFieldsToRaces < ActiveRecord::Migration[7.0]
  def change
    add_column :races, :sprint_quali_time, :string
    add_column :races, :sprint_time, :string
  end
end
