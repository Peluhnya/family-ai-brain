require "test_helper"

module CalendarSync
  class AppleCalendarAdapterTest < ActiveSupport::TestCase
    test "fetches and normalizes events from every selected iCloud calendar" do
      connection = families(:one).calendar_connections.create!(
        provider: "apple_calendar", remote_calendar_id: "selected", access_token: "app-password",
        settings: { "apple_id" => "family@icloud.com", "apple_calendar_ids" => %w[https://caldav.test/home/one/ https://caldav.test/home/two/] }
      )
      client = Object.new
      client.define_singleton_method(:calendar_data) do |url|
        uid = url.include?("one") ? "event-one" : "event-two"
        [ "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:#{uid}\r\nSUMMARY:Family\\, event\r\nDTSTART:20260801T100000Z\r\nDTEND:20260801T110000Z\r\nLOCATION:Home\r\nEND:VEVENT\r\nEND:VCALENDAR" ]
      end

      AppleCaldavClient.stub(:new, client) do
        events = AppleCalendarAdapter.new(connection:).fetch_events
        assert_equal 2, events.size
        assert_equal [ "Family, event" ], events.pluck(:title).uniq
        assert events.all? { |event| event[:external_id].match?(/\A[0-9a-f]{64}:event-(one|two):\z/) }
      end
    end

    test "requires at least one selected Apple calendar" do
      connection = families(:one).calendar_connections.create!(provider: "apple_calendar", access_token: "password", settings: { "apple_id" => "user@icloud.com" })
      error = assert_raises(RuntimeError) { AppleCalendarAdapter.new(connection:).fetch_events }
      assert_equal "Choose at least one Apple calendar to sync.", error.message
    end
  end
end
