class ScheduleCalendarSyncsJob < ApplicationJob
  queue_as :default

  def perform
    CalendarConnection.where(active: true).find_each do |connection|
      CalendarConnectionSyncJob.perform_later(connection.id) if connection.ready_for_remote_sync?
    end
  end
end
