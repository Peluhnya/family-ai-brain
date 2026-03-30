module CalendarSync
  class ProviderAdapter
    def self.for(connection)
      case connection.provider
      when "google_calendar" then CalendarSync::GoogleCalendarAdapter.new(connection:)
      when "apple_calendar" then CalendarSync::AppleCalendarAdapter.new(connection:)
      when "outlook_calendar" then CalendarSync::OutlookCalendarAdapter.new(connection:)
      else
        raise "Unsupported calendar provider: #{connection.provider}"
      end
    end
  end
end
