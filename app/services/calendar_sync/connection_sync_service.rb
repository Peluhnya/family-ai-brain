module CalendarSync
  class ConnectionSyncService
    def initialize(connection:)
      @connection = connection
      @family = connection.family
    end

    def call
      adapter = CalendarSync::ProviderAdapter.for(@connection)
      remote_events = adapter.fetch_events
      imported = 0

      remote_events.each do |payload|
        CalendarSync::UpsertEventService.new(family: @family, payload: normalize_payload(payload)).call
        imported += 1
      end

      @connection.update!(last_synced_at: Time.current, last_error: nil)
      { imported: imported, error: nil }
    rescue StandardError => e
      @connection.update(last_error: e.message)
      { imported: 0, error: e.message }
    end

    private

    def normalize_payload(payload)
      external_id = payload[:external_id].to_s.strip.presence
      source_key = @connection.source_key

      {
        title: payload[:title].to_s.strip.presence || "External event",
        start_time: payload[:start_time],
        end_time: payload[:end_time],
        location: payload[:location].to_s.strip.presence,
        external_id: external_id,
        source: source_key,
        source_key: source_key,
        sync_fingerprint: Event.sync_fingerprint_for(source_key:, external_id:),
        deleted: payload[:deleted]
      }
    end
  end
end
