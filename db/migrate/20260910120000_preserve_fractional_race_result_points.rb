require "csv"

class PreserveFractionalRaceResultPoints < ActiveRecord::Migration[7.0]
  class MigrationRaceResult < ActiveRecord::Base
    self.table_name = "race_results"
  end

  def up
    change_column :race_results, :points, :decimal, precision: 8, scale: 2

    archive = Rails.root.join("db/archive/results.csv")
    return unless archive.exist?

    CSV.foreach(archive, headers: true) do |row|
      points = BigDecimal(row["points"].to_s)
      next if points.frac.zero?

      MigrationRaceResult.where(kaggle_id: row["resultId"]).update_all(points: points)
    end
  end

  def down
    change_column :race_results, :points, :integer
  end
end
