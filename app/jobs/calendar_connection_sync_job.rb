class CalendarConnectionSyncJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(calendar_connection_id) { calendar_connection_id }, duration: 10.minutes

  def perform(calendar_connection_id)
    connection = CalendarConnection.find_by(id: calendar_connection_id)
    return unless connection&.active? && connection.ready_for_remote_sync?

    CalendarSync::ConnectionSyncService.new(connection:).call
  end
end
