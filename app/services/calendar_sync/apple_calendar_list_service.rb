module CalendarSync
  class AppleCalendarListService
    def initialize(connection:)
      @connection = connection
    end

    def call
      raise "Calendar selection is available only for Apple Calendar connections." unless @connection.apple_calendar?

      AppleCaldavClient.new(connection: @connection).calendars
    end
  end
end
