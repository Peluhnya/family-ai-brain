class CreateDailyConversations < ActiveRecord::Migration[8.1]
  def up
    create_table :conversations do |t|
      t.references :family, null: false, foreign_key: true
      t.string :title, null: false
      t.date :started_on, null: false
      t.string :status, null: false, default: "active"
      t.datetime :last_message_at
      t.integer :messages_count, null: false, default: 0

      t.timestamps
    end

    add_index :conversations, %i[family_id started_on], unique: true
    add_index :conversations, %i[family_id status last_message_at]

    add_reference :ai_interactions, :conversation, null: true, foreign_key: true
    add_reference :ai_interactions,
      :reply_to,
      null: true,
      foreign_key: { to_table: :ai_interactions, on_delete: :nullify }
    add_index :ai_interactions,
      %i[conversation_id id],
      name: "index_ai_interactions_on_conversation_and_id"

    execute <<~SQL.squish
      INSERT INTO conversations (
        family_id, title, started_on, status, last_message_at, messages_count, created_at, updated_at
      )
      SELECT
        family_id,
        TO_CHAR(created_at::date, 'DD.MM.YYYY'),
        created_at::date,
        'archived',
        MAX(created_at),
        COUNT(*),
        MIN(created_at),
        MAX(updated_at)
      FROM ai_interactions
      GROUP BY family_id, created_at::date
    SQL

    execute <<~SQL.squish
      UPDATE ai_interactions AS interaction
      SET conversation_id = conversation.id
      FROM conversations AS conversation
      WHERE conversation.family_id = interaction.family_id
        AND conversation.started_on = interaction.created_at::date
    SQL

    execute <<~SQL.squish
      UPDATE conversations AS conversation
      SET status = 'active'
      WHERE conversation.started_on = (
        SELECT MAX(latest.started_on)
        FROM conversations AS latest
        WHERE latest.family_id = conversation.family_id
      )
    SQL

    execute <<~SQL.squish
      WITH ordered_interactions AS (
        SELECT
          id,
          role,
          LAG(id) OVER (PARTITION BY conversation_id ORDER BY id) AS previous_id,
          LAG(role) OVER (PARTITION BY conversation_id ORDER BY id) AS previous_role
        FROM ai_interactions
      )
      UPDATE ai_interactions AS assistant
      SET reply_to_id = ordered.previous_id
      FROM ordered_interactions AS ordered
      WHERE assistant.id = ordered.id
        AND ordered.role = 'assistant'
        AND ordered.previous_role = 'user'
    SQL

    change_column_null :ai_interactions, :conversation_id, false
  end

  def down
    remove_index :ai_interactions, name: "index_ai_interactions_on_conversation_and_id"
    remove_reference :ai_interactions, :reply_to, foreign_key: { to_table: :ai_interactions }
    remove_reference :ai_interactions, :conversation, foreign_key: true
    drop_table :conversations
  end
end
