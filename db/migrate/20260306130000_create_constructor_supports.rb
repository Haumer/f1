class CreateConstructorSupports < ActiveRecord::Migration[7.0]
  def change
    create_table :constructor_supports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :constructor, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.boolean :active, default: true, null: false
      t.boolean :bonus_granted, default: false, null: false
      t.datetime :ended_at
      t.timestamps
    end

    add_index :constructor_supports, [:user_id, :season_id, :active], unique: true, where: "active = true", name: "idx_one_active_support_per_user_season"

    # Remove old column from users
    remove_foreign_key :users, :constructors, column: :supported_constructor_id
    remove_index :users, :supported_constructor_id
    remove_column :users, :supported_constructor_id, :bigint
  end
end
