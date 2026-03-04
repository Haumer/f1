class AddTierToDriverBadges < ActiveRecord::Migration[7.0]
  def change
    add_column :driver_badges, :tier, :string
  end
end
