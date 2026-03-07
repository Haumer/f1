class DropAiAnalyses < ActiveRecord::Migration[7.0]
  def up
    drop_table :ai_analyses
  end

  def down
    create_table :ai_analyses do |t|
      t.references :race, null: false, foreign_key: true
      t.string :analysis_type, null: false
      t.text :content
      t.jsonb :picks
      t.jsonb :sources
      t.datetime :generated_at
      t.timestamps
    end
    add_index :ai_analyses, [:race_id, :analysis_type], unique: true
  end
end
