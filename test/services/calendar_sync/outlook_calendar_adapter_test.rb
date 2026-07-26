require "test_helper"

module CalendarSync
  class OutlookCalendarAdapterTest < ActiveSupport::TestCase
    setup do
      @connection = families(:one).calendar_connections.create!(provider: "outlook_calendar", remote_calendar_id: "one,two",
        access_token: "token", settings: { "outlook_calendar_ids" => %w[one two] })
    end

    test "fetches all pages from selected calendars and namespaces event ids" do
      adapter = OutlookCalendarAdapter.new(connection: @connection)
      adapter.define_singleton_method(:get) do |url, refreshed: false|
        raise "unexpected refresh" if refreshed
        if url.include?("calendars/one/")
          { "value" => [ { "id" => "same", "subject" => "Dentist", "start" => { "dateTime" => "2026-08-01T10:00:00Z" },
            "end" => { "dateTime" => "2026-08-01T11:00:00Z" }, "location" => { "displayName" => "Clinic" } } ] }
        elsif url.include?("calendars/two/")
          { "value" => [ { "id" => "same", "subject" => "Holiday", "start" => { "dateTime" => "2026-08-02T00:00:00Z" },
            "end" => { "dateTime" => "2026-08-03T00:00:00Z" }, "isAllDay" => true } ] }
        else
          raise "unexpected URL: #{url}"
        end
      end

      events = adapter.fetch_events
      assert_equal %w[one:same two:same], events.pluck(:external_id)
      assert_equal [ false, true ], events.pluck(:all_day)
      assert_equal "Clinic", events.first[:location]
    end

    test "requires at least one selected calendar" do
      @connection.update!(settings: { "outlook_calendar_ids" => [] })
      error = assert_raises(RuntimeError) { OutlookCalendarAdapter.new(connection: @connection).fetch_events }
      assert_equal "Choose at least one Outlook calendar to sync.", error.message
    end
  end
end
