require "test_helper"

module CalendarSync
  class ConnectionSyncServiceTest < ActiveSupport::TestCase
    test "imports same Google event id from different calendars as separate events" do
      family = families(:one)
      connection = family.calendar_connections.create!(
        provider: "google_calendar",
        remote_calendar_id: "all",
        access_token: "test-token"
      )
      adapter = Object.new
      adapter.define_singleton_method(:fetch_events) do
        [
          { external_id: "primary:event-1", title: "Основний", start_time: Time.zone.parse("2026-08-01"), end_time: Time.zone.parse("2026-08-02"), all_day: true },
          { external_id: "shared:event-1", title: "Спільний", start_time: Time.zone.parse("2026-08-01 10:00"), end_time: Time.zone.parse("2026-08-01 11:00"), all_day: false }
        ]
      end

      assert_difference -> { family.events.count }, 2 do
        ProviderAdapter.stub(:for, adapter) do
          result = ConnectionSyncService.new(connection:).call
          assert_nil result[:error]
          assert_equal 2, result[:imported]
        end
      end

      imported = family.events.where(source_key: "google_calendar").order(:title)
      assert_equal [ "Спільний", "Основний" ], imported.map(&:title)
      assert_equal [ false, true ], imported.map(&:all_day?)
    end
  end
end
