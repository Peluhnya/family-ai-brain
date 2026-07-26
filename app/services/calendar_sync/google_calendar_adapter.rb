module CalendarSync
  class GoogleCalendarAdapter
    API_BASE_URL = "https://www.googleapis.com/calendar/v3".freeze

    def initialize(connection:)
      @connection = connection
    end

    def fetch_events
      raise "Google Calendar connection is missing credentials." unless @connection.ready_for_remote_sync?

      selected_calendar_ids.flat_map { |calendar_id| fetch_calendar_events(calendar_id) }
    end

    private

    def selected_calendar_ids
      ids = Array(@connection.settings["google_calendar_ids"]).compact_blank.uniq
      raise "Choose at least one Google calendar to sync." if ids.empty?

      ids
    end

    def fetch_calendar_events(calendar_id)
      events = []
      page_token = nil

      loop do
        response = get_events_page(calendar_id:, page_token:)
        events.concat(Array(response["items"]).map { |item| normalize_event(item, calendar_id:) })
        page_token = response["nextPageToken"]
        break if page_token.blank?
      end

      events
    end

    def get_events_page(calendar_id:, page_token:, refreshed: false)
      uri = URI("#{API_BASE_URL}/calendars/#{CGI.escape(calendar_id)}/events")
      params = {
        maxResults: 250,
        singleEvents: true,
        showDeleted: true
      }
      params[:pageToken] = page_token if page_token.present?
      uri.query = URI.encode_www_form(params)

      response = perform_request(uri)
      body = JSON.parse(response.body)

      case response.code.to_i
      when 200 then body
      when 401
        raise "Google Calendar access token refresh failed." if refreshed

        refresh_access_token!
        get_events_page(calendar_id:, page_token:, refreshed: true)
      else
        raise(body.dig("error", "message") || "Google Calendar events request failed.")
      end
    end

    def perform_request(uri)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{current_access_token}"

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
    end

    def current_access_token
      return @current_access_token if defined?(@current_access_token) && @current_access_token.present?
      return @current_access_token = @connection.access_token if @connection.access_token.present? && @connection.refresh_token.blank?

      refresh_access_token!
    end

    def refresh_access_token!
      @current_access_token = CalendarSync::GoogleOauthService.new(connection: @connection).refresh_access_token!
    end

    def normalize_event(item, calendar_id:)
      start_time = extract_time(item["start"])
      end_time = extract_time(item["end"])

      {
        # Google event ids are unique only inside a calendar. Prefixing the id
        # prevents an event in a shared calendar from replacing another one.
        external_id: "#{calendar_id}:#{item['id']}",
        external_calendar_id: calendar_id,
        external_event_id: item["id"],
        external_updated_at: item["updated"].present? ? Time.zone.parse(item["updated"]) : nil,
        title: item["summary"].presence || "Google Calendar event",
        start_time: start_time,
        end_time: end_time,
        all_day: item.dig("start", "date").present?,
        location: item["location"],
        deleted: item["status"] == "cancelled"
      }
    end

    def extract_time(value)
      return if value.blank?

      if value["dateTime"].present?
        Time.zone.parse(value["dateTime"])
      elsif value["date"].present?
        Time.zone.parse("#{value['date']} 00:00:00")
      end
    end
  end
end
