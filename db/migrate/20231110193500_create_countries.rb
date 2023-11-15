class CreateCountries < ActiveRecord::Migration[7.0]
  def change
    create_table :countries do |t|
      t.string :nationality
      t.string :two_letter_country_code
      t.string :name
      t.string :three_letter_country_code

      t.timestamps
    end
  end
end
