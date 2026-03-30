module CalendarSync
  class GoogleCalendarListService
    API_BASE_URL = "https://www.googleapis.com/calendar/v3".freeze

    def initialize(connection:)
      @connection = connection
    end

    def call
      raise "Google Calendar connection is missing credentials." unless @connection.google_calendar?
      raise "Google Calendar connection is not authorized yet." if @connection.access_token.blank? && @connection.refresh_token.blank?

      calendars = []
      page_token = nil

      loop do
        response = get_calendar_list_page(page_token:)
        calendars.concat(Array(response["items"]).map { |item| normalize_calendar(item) })
        page_token = response["nextPageToken"]
        break if page_token.blank?
      end

      calendars
    end

    private

    def get_calendar_list_page(page_token:, refreshed: false)
      uri = URI("#{API_BASE_URL}/users/me/calendarList")
      query = { maxResults: 250 }
      query[:pageToken] = page_token if page_token.present?
      uri.query = URI.encode_www_form(query)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{current_access_token}"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      body = JSON.parse(response.body)

      case response.code.to_i
      when 200 then body
      when 401
        raise "Google Calendar access token refresh failed." if refreshed

        refresh_access_token!
        get_calendar_list_page(page_token:, refreshed: true)
      else
        raise(body.dig("error", "message") || "Google calendar list request failed.")
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

    def normalize_calendar(item)
      {
        id: item["id"],
        summary: item["summary"].presence || item["id"],
        description: item["description"],
        primary: item["primary"] == true,
        access_role: item["accessRole"],
        time_zone: item["timeZone"],
        selected: item["selected"] == true
      }
    end
  end
end
