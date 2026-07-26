module CalendarSync
  class OutlookCalendarListService
    CALENDARS_URL = "https://graph.microsoft.com/v1.0/me/calendars?%24select=id,name,isDefaultCalendar,canEdit".freeze

    def initialize(connection:)
      @connection = connection
    end

    def call
      raise "Outlook Calendar connection is missing credentials." unless @connection.outlook_calendar?
      raise "Outlook Calendar connection is not authorized yet." if @connection.access_token.blank? && @connection.refresh_token.blank?

      calendars = []
      url = CALENDARS_URL
      while url.present?
        body = get(url)
        calendars.concat(Array(body["value"]).map { |item| normalize(item) })
        url = body["@odata.nextLink"]
      end
      calendars
    end

    private

    def get(url, refreshed: false)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{current_access_token}"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      body = JSON.parse(response.body)
      return body if response.code.to_i == 200
      if response.code.to_i == 401 && !refreshed
        refresh_access_token!
        return get(url, refreshed: true)
      end

      raise(body.dig("error", "message") || "Outlook calendar list request failed.")
    end

    def current_access_token
      return @current_access_token if defined?(@current_access_token) && @current_access_token.present?
      return @current_access_token = @connection.access_token if @connection.access_token.present? && @connection.refresh_token.blank?

      refresh_access_token!
    end

    def refresh_access_token!
      @current_access_token = OutlookOauthService.new(connection: @connection).refresh_access_token!
    end

    def normalize(item)
      { id: item["id"], summary: item["name"].presence || item["id"], primary: item["isDefaultCalendar"] == true,
        can_edit: item["canEdit"] == true }
    end
  end
end
