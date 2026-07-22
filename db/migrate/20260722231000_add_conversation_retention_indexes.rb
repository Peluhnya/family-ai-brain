class AddConversationRetentionIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :conversations, :last_message_at, name: "index_conversations_for_retention"
    add_index :ai_interactions, :created_at, name: "index_ai_interactions_for_retention"
  end
end
