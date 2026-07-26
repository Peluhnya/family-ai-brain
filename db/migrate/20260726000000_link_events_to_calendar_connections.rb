class LinkEventsToCalendarConnections < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :calendar_connection, foreign_key: true
    add_column :events, :external_calendar_id, :string
    add_column :events, :external_event_id, :string
    add_column :events, :external_updated_at, :datetime
  end
end
