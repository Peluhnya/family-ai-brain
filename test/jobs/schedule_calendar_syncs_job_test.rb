require "test_helper"

class ScheduleCalendarSyncsJobTest < ActiveJob::TestCase
  test "enqueues sync only for active ready connections" do
    family = families(:one)
    ready = family.calendar_connections.create!(provider: "google_calendar", remote_calendar_id: "primary", access_token: "token")
    family.calendar_connections.create!(provider: "google_calendar", remote_calendar_id: "inactive", access_token: "token", active: false)
    family.calendar_connections.create!(provider: "google_calendar", remote_calendar_id: "missing-token")

    assert_enqueued_with(job: CalendarConnectionSyncJob, args: [ ready.id ]) do
      assert_enqueued_jobs 1 do
        ScheduleCalendarSyncsJob.perform_now
      end
    end
  end
end
