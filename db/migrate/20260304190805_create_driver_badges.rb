class CreateDriverBadges < ActiveRecord::Migration[7.0]
  def change
    create_table :driver_badges do |t|
      t.references :driver, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.string :description
      t.string :icon
      t.string :color
      t.string :value

      t.timestamps
    end

    add_index :driver_badges, [:driver_id, :key], unique: true
  end
end
