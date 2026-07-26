module CalendarSync
  class OutlookCalendarAdapter
    def initialize(connection:)
      @connection = connection
    end

    def fetch_events
      raise "Outlook Calendar connection is missing credentials." unless @connection.ready_for_remote_sync?

      selected_calendar_ids.flat_map { |calendar_id| fetch_calendar_events(calendar_id) }
    end

    private

    def selected_calendar_ids
      ids = Array(@connection.settings["outlook_calendar_ids"]).compact_blank.uniq
      raise "Choose at least one Outlook calendar to sync." if ids.empty?

      ids
    end

    def fetch_calendar_events(calendar_id)
      events = []
      url = "https://graph.microsoft.com/v1.0/me/calendars/#{CGI.escape(calendar_id)}/events?%24top=250&%24select=id,subject,start,end,isAllDay,location,isCancelled,lastModifiedDateTime"
      while url.present?
        body = get(url)
        events.concat(Array(body["value"]).map { |item| normalize_event(item, calendar_id:) })
        url = body["@odata.nextLink"]
      end
      events
    end

    def get(url, refreshed: false)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{current_access_token}"
      request["Prefer"] = 'outlook.timezone="UTC"'
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      body = JSON.parse(response.body)
      return body if response.code.to_i == 200
      if response.code.to_i == 401 && !refreshed
        refresh_access_token!
        return get(url, refreshed: true)
      end

      raise(body.dig("error", "message") || "Outlook Calendar events request failed.")
    end

    def current_access_token
      return @current_access_token if defined?(@current_access_token) && @current_access_token.present?
      return @current_access_token = @connection.access_token if @connection.access_token.present? && @connection.refresh_token.blank?

      refresh_access_token!
    end

    def refresh_access_token!
      @current_access_token = OutlookOauthService.new(connection: @connection).refresh_access_token!
    end

    def normalize_event(item, calendar_id:)
      {
        external_id: "#{calendar_id}:#{item['id']}",
        external_calendar_id: calendar_id,
        external_event_id: item["id"],
        external_updated_at: item["lastModifiedDateTime"].present? ? Time.zone.parse(item["lastModifiedDateTime"]) : nil,
        title: item["subject"].presence || "Outlook Calendar event",
        start_time: parse_time(item["start"]),
        end_time: parse_time(item["end"]),
        all_day: item["isAllDay"] == true,
        location: item.dig("location", "displayName"),
        deleted: item["isCancelled"] == true
      }
    end

    def parse_time(value)
      Time.zone.parse(value["dateTime"]) if value&.dig("dateTime").present?
    end
  end
end
