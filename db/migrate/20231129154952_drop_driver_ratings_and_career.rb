class DropDriverRatingsAndCareer < ActiveRecord::Migration[7.0]
  def change
    drop_table :driver_ratings
    drop_table :careers
  end
end
