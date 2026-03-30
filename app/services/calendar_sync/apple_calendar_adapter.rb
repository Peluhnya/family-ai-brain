module CalendarSync
  class AppleCalendarAdapter
    def initialize(connection:)
      @connection = connection
    end

    def fetch_events
      raise "Apple Calendar sync is not configured yet. Connection model and upsert layer are ready; CalDAV/ICS fetch is the next step."
    end
  end
end
