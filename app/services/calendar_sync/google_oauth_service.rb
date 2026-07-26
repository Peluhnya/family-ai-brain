module CalendarSync
  class GoogleOauthService
    AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
    TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
    SCOPE = "https://www.googleapis.com/auth/calendar.readonly".freeze

    def initialize(connection:, redirect_uri: nil)
      @connection = connection
      @redirect_uri = redirect_uri
    end

    def authorization_url(state:)
      raise "Google redirect URI is missing." if @redirect_uri.blank?

      query = {
        client_id: client_id,
        redirect_uri: @redirect_uri,
        response_type: "code",
        scope: SCOPE,
        access_type: "offline",
        include_granted_scopes: "true",
        prompt: "consent",
        state:
      }

      "#{AUTHORIZE_URL}?#{URI.encode_www_form(query)}"
    end

    def exchange_code!(code:)
      raise "Google redirect URI is missing." if @redirect_uri.blank?

      payload = post_form(
        TOKEN_URL,
        code:,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: @redirect_uri,
        grant_type: "authorization_code"
      )

      persist_tokens!(payload, preserve_refresh_token: false)
    end

    def refresh_access_token!
      raise "Google refresh token is missing." if @connection.refresh_token.blank?

      payload = post_form(
        TOKEN_URL,
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: @connection.refresh_token,
        grant_type: "refresh_token"
      )

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

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      body = JSON.parse(response.body)
      return body if response.is_a?(Net::HTTPSuccess)

      raise(body.dig("error_description") || body.dig("error", "message") || body["error"] || "Google OAuth request failed.")
    end

    def client_id
      ENV["GOOGLE_CLIENT_ID"].presence || Rails.application.credentials.dig(:google, :client_id).presence ||
        raise(KeyError, "GOOGLE_CLIENT_ID is missing")
    end

    def client_secret
      ENV["GOOGLE_CLIENT_SECRET"].presence || Rails.application.credentials.dig(:google, :client_secret).presence ||
        raise(KeyError, "GOOGLE_CLIENT_SECRET is missing")
    end
  end
end
