class CreateAdminAlerts < ActiveRecord::Migration[7.0]
  def change
    create_table :admin_alerts do |t|
      t.string :title, null: false
      t.text :message
      t.string :severity, default: "error"
      t.string :source
      t.boolean :resolved, default: false
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :admin_alerts, :resolved
    add_index :admin_alerts, :created_at
  end
end
