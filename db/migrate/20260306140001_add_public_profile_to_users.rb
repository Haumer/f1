class AddPublicProfileToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :public_profile, :boolean, default: true, null: false
  end
end
