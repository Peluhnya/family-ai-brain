class CreateAiActionProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_action_proposals do |t|
      t.references :family, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :source_ai_interaction, null: false, foreign_key: { to_table: :ai_interactions }
      t.references :confirmation_ai_interaction, foreign_key: { to_table: :ai_interactions }
      t.string :action_kind, null: false
      t.string :state, null: false, default: "awaiting_clarification"
      t.string :intent_strength, null: false, default: "explicit"
      t.string :risk, null: false, default: "low"
      t.string :entity_type
      t.bigint :entity_id
      t.string :action_fingerprint, null: false
      t.string :group_key
      t.text :payload
      t.text :evidence
      t.jsonb :missing_fields, null: false, default: []
      t.datetime :expires_at
      t.datetime :executed_at
      t.text :error_message

      t.timestamps
    end

    add_index :ai_action_proposals,
      %i[source_ai_interaction_id action_fingerprint],
      unique: true,
      name: "index_ai_action_proposals_on_source_and_fingerprint"
    add_index :ai_action_proposals, %i[family_id state expires_at]
    add_index :ai_action_proposals, %i[conversation_id state created_at]
    add_index :ai_action_proposals, %i[entity_type entity_id]
  end
end
