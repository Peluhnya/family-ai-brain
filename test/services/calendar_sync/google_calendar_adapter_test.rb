require "test_helper"

module CalendarSync
  class GoogleCalendarAdapterTest < ActiveSupport::TestCase
    setup do
      @connection = families(:one).calendar_connections.create!(
        provider: "google_calendar",
        remote_calendar_id: "all",
        access_token: "test-token",
        settings: { "google_calendar_ids" => [ "primary@example.com", "shared@example.com" ] }
      )
    end

    test "fetches every page from every Google calendar and namespaces event ids" do
      adapter = GoogleCalendarAdapter.new(connection: @connection)
      adapter.define_singleton_method(:get_events_page) do |calendar_id:, page_token:, refreshed: false|
        raise "unexpected refresh" if refreshed

        case [ calendar_id, page_token ]
        when [ "primary@example.com", nil ]
          {
            "items" => [ {
              "id" => "same-id",
              "summary" => "Відпустка",
              "start" => { "date" => "2026-08-01" },
              "end" => { "date" => "2026-08-03" }
            } ],
            "nextPageToken" => "page-2"
          }
        when [ "primary@example.com", "page-2" ]
          { "items" => [], "nextSyncToken" => "ignored-per-calendar-token" }
        when [ "shared@example.com", nil ]
          {
            "items" => [ {
              "id" => "same-id",
              "summary" => "Спільна зустріч",
              "start" => { "dateTime" => "2026-08-04T10:00:00+03:00" },
              "end" => { "dateTime" => "2026-08-04T11:00:00+03:00" }
            } ]
          }
        else
          raise "unexpected request: #{calendar_id.inspect}, #{page_token.inspect}"
        end
      end

      events = adapter.fetch_events

      assert_equal 2, events.size
      assert_equal [ "primary@example.com:same-id", "shared@example.com:same-id" ], events.pluck(:external_id)
      assert_equal [ true, false ], events.pluck(:all_day)
    end

    test "requires at least one selected calendar" do
      @connection.update!(settings: { "google_calendar_ids" => [] })

      error = assert_raises(RuntimeError) { GoogleCalendarAdapter.new(connection: @connection).fetch_events }

      assert_equal "Choose at least one Google calendar to sync.", error.message
    end
  end
end
