class CreateAiAnalyses < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_analyses do |t|
      t.references :race, null: false, foreign_key: true
      t.string :analysis_type, null: false, default: 'race_preview'
      t.text :content
      t.jsonb :picks, default: {}
      t.jsonb :sources, default: []
      t.datetime :generated_at

      t.timestamps
    end
  end
end
