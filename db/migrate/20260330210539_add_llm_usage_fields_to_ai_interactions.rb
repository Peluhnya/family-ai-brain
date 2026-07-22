class AddLlmUsageFieldsToAiInteractions < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_interactions, :input_tokens, :integer
    add_column :ai_interactions, :output_tokens, :integer
    add_column :ai_interactions, :system_prompt_tokens, :integer
    add_column :ai_interactions, :system_prompt_chars, :integer
    add_column :ai_interactions, :short_term_tokens, :integer
    add_column :ai_interactions, :short_term_message_count, :integer
    add_column :ai_interactions, :user_message_tokens, :integer
    add_column :ai_interactions, :prompt_version, :string
    add_column :ai_interactions, :llm_metadata, :jsonb, default: {}, null: false

    add_index :ai_interactions, :prompt_version
    add_index :ai_interactions, :input_tokens
  end
end
