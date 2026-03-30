module CalendarSync
  class OutlookCalendarAdapter
    def initialize(connection:)
      @connection = connection
    end

    def fetch_events
      raise "Outlook Calendar sync is not configured yet. Connection model and upsert layer are ready; Microsoft Graph fetch is the next step."
    end
  end
end
