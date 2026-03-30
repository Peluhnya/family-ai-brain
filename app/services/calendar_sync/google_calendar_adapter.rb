module CalendarSync
  class GoogleCalendarAdapter
    API_BASE_URL = "https://www.googleapis.com/calendar/v3".freeze

    def initialize(connection:)
      @connection = connection
    end

    def fetch_events
      raise "Google Calendar connection is missing credentials." unless @connection.ready_for_remote_sync?

      events = []
      page_token = nil

      loop do
        response = get_events_page(page_token:)
        events.concat(Array(response["items"]).map { |item| normalize_event(item) })
        page_token = response["nextPageToken"]

        if page_token.blank?
          @connection.update!(sync_cursor: response["nextSyncToken"].presence || @connection.sync_cursor)
          break
        end
      end

      events
    rescue CalendarSync::GoogleCalendarAdapter::FullSyncRequired
      @connection.update!(sync_cursor: nil)
      retry
    end

    class FullSyncRequired < StandardError; end

    private

    def get_events_page(page_token:, refreshed: false)
      uri = URI("#{API_BASE_URL}/calendars/#{CGI.escape(@connection.effective_remote_calendar_id)}/events")
      params = {
        maxResults: 250,
        singleEvents: true,
        showDeleted: true
      }
      params[:syncToken] = @connection.sync_cursor if @connection.sync_cursor.present?
      params[:pageToken] = page_token if page_token.present?
      uri.query = URI.encode_www_form(params)

      response = perform_request(uri)
      body = JSON.parse(response.body)

      case response.code.to_i
      when 200 then body
      when 401
        raise "Google Calendar access token refresh failed." if refreshed

        refresh_access_token!
        get_events_page(page_token:, refreshed: true)
      when 410
        raise FullSyncRequired
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

    def normalize_event(item)
      start_time = extract_time(item["start"])
      end_time = extract_time(item["end"])

      {
        external_id: item["id"],
        title: item["summary"].presence || "Google Calendar event",
        start_time: start_time,
        end_time: end_time,
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
