class AddActiveToConstructors < ActiveRecord::Migration[7.0]
  def change
    add_column :constructors, :active, :boolean
  end
end
