class AddRetentionIndexToAiEffects < ActiveRecord::Migration[8.1]
  def change
    add_index :ai_effects, %i[status created_at], name: "index_ai_effects_on_status_and_created_at"
  end
end
