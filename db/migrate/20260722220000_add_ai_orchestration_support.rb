class AddAiOrchestrationSupport < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :all_day, :boolean, default: false, null: false

    create_table :ai_effects do |t|
      t.references :family, null: false, foreign_key: true
      t.references :source_ai_interaction, null: false, foreign_key: { to_table: :ai_interactions }
      t.string :action_type, null: false
      t.string :status, null: false, default: "pending"
      t.string :entity_type
      t.bigint :entity_id
      t.string :action_fingerprint, null: false
      t.text :details
      t.text :error_message

      t.timestamps
    end

    add_index :ai_effects,
      %i[source_ai_interaction_id action_fingerprint],
      unique: true,
      name: "index_ai_effects_on_source_and_fingerprint"
    add_index :ai_effects, %i[entity_type entity_id]
    add_index :ai_effects, %i[family_id created_at]
  end
end
