require "test_helper"

class CalendarConnectionSyncJobTest < ActiveJob::TestCase
  test "syncs an active ready connection" do
    connection = families(:one).calendar_connections.create!(
      provider: "google_calendar", remote_calendar_id: "primary", access_token: "token"
    )
    service = Minitest::Mock.new
    service.expect(:call, { imported: 1, error: nil })

    CalendarSync::ConnectionSyncService.stub(:new, service) do
      CalendarConnectionSyncJob.perform_now(connection.id)
    end

    service.verify
  end

  test "ignores missing connections" do
    assert_nothing_raised { CalendarConnectionSyncJob.perform_now(-1) }
  end
end
