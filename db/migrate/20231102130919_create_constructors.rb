class CreateConstructors < ActiveRecord::Migration[7.0]
  def change
    create_table :constructors do |t|
      t.integer :kaggle_id
      t.string :constructor_ref
      t.string :name
      t.string :nationality
      t.string :url

      t.timestamps
    end
  end
end
