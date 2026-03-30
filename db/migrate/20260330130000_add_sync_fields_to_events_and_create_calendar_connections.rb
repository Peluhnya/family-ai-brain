class AddSyncFieldsToEventsAndCreateCalendarConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :source_key, :string
    add_column :events, :sync_fingerprint, :string
    add_index :events, :source_key
    add_index :events, [:family_id, :sync_fingerprint], unique: true, where: "sync_fingerprint IS NOT NULL", name: "index_events_on_family_and_sync_fingerprint"

    create_table :calendar_connections do |t|
      t.references :family, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :remote_calendar_key
      t.string :connection_fingerprint
      t.string :display_name
      t.string :remote_calendar_id
      t.text :access_token
      t.text :refresh_token
      t.text :sync_cursor
      t.jsonb :settings, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.datetime :last_synced_at
      t.text :last_error

      t.timestamps
    end

    add_index :calendar_connections, :provider
    add_index :calendar_connections, [:family_id, :connection_fingerprint], unique: true, where: "connection_fingerprint IS NOT NULL", name: "index_calendar_connections_on_family_and_fingerprint"
  end
end
