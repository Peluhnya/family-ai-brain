module CalendarSync
  class OutlookOauthService
    AUTHORIZE_URL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize".freeze
    TOKEN_URL = "https://login.microsoftonline.com/common/oauth2/v2.0/token".freeze
    SCOPE = "offline_access Calendars.Read".freeze

    def initialize(connection:, redirect_uri: nil)
      @connection = connection
      @redirect_uri = redirect_uri
    end

    def authorization_url(state:)
      raise "Outlook redirect URI is missing." if @redirect_uri.blank?

      query = {
        client_id: client_id,
        redirect_uri: @redirect_uri,
        response_type: "code",
        response_mode: "query",
        scope: SCOPE,
        state:
      }
      "#{AUTHORIZE_URL}?#{URI.encode_www_form(query)}"
    end

    def exchange_code!(code:)
      raise "Outlook redirect URI is missing." if @redirect_uri.blank?

      payload = post_form(TOKEN_URL, client_id:, client_secret:, code:, redirect_uri: @redirect_uri,
        grant_type: "authorization_code", scope: SCOPE)
      persist_tokens!(payload, preserve_refresh_token: false)
    end

    def refresh_access_token!
      raise "Outlook refresh token is missing." if @connection.refresh_token.blank?

      payload = post_form(TOKEN_URL, client_id:, client_secret:, refresh_token: @connection.refresh_token,
        grant_type: "refresh_token", scope: SCOPE)
      persist_tokens!(payload, preserve_refresh_token: true)
      payload.fetch("access_token")
    end

    private

    def persist_tokens!(payload, preserve_refresh_token:)
      @connection.update!(
        access_token: payload["access_token"].presence || @connection.access_token,
        refresh_token: payload["refresh_token"].presence || (preserve_refresh_token ? @connection.refresh_token : nil),
        last_error: nil
      )
    end

    def post_form(url, params)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = URI.encode_www_form(params.compact)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      body = JSON.parse(response.body)
      return body if response.is_a?(Net::HTTPSuccess)

      raise(body.dig("error", "message") || body["error_description"] || body["error"] || "Outlook OAuth request failed.")
    end

    def client_id
      ENV["MICROSOFT_CLIENT_ID"].presence || Rails.application.credentials.dig(:microsoft, :client_id).presence ||
        raise(KeyError, "MICROSOFT_CLIENT_ID is missing")
    end

    def client_secret
      ENV["MICROSOFT_CLIENT_SECRET"].presence || Rails.application.credentials.dig(:microsoft, :client_secret).presence ||
        raise(KeyError, "MICROSOFT_CLIENT_SECRET is missing")
    end
  end
end
