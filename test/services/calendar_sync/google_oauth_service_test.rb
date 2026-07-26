require "test_helper"

module CalendarSync
  class GoogleOauthServiceTest < ActiveSupport::TestCase
    setup do
      @connection = families(:one).calendar_connections.create!(
        provider: "google_calendar",
        access_token: "old-access-token",
        refresh_token: "old-refresh-token"
      )
      @service = GoogleOauthService.new(connection: @connection, redirect_uri: "https://app.example.com/calendar_connections/google_callback")
    end

    test "builds authorization URL for offline read-only access" do
      url = URI(@service.stub(:client_id, "client-id") { @service.authorization_url(state: "secure-state") })
      query = Rack::Utils.parse_query(url.query)

      assert_equal GoogleOauthService::AUTHORIZE_URL, "#{url.scheme}://#{url.host}#{url.path}"
      assert_equal "client-id", query["client_id"]
      assert_equal GoogleOauthService::SCOPE, query["scope"]
      assert_equal "offline", query["access_type"]
      assert_equal "consent", query["prompt"]
      assert_equal "secure-state", query["state"]
    end

    test "authorization code exchange does not retain a refresh token from another Google account" do
      payload = { "access_token" => "new-access-token" }

      @service.stub(:post_form, payload) do
        @service.stub(:client_id, "client-id") do
          @service.stub(:client_secret, "client-secret") do
            @service.exchange_code!(code: "authorization-code")
          end
        end
      end

      @connection.reload
      assert_equal "new-access-token", @connection.access_token
      assert_nil @connection.refresh_token
    end

    test "token refresh retains the existing refresh token" do
      payload = { "access_token" => "refreshed-access-token" }

      @service.stub(:post_form, payload) do
        @service.stub(:client_id, "client-id") do
          @service.stub(:client_secret, "client-secret") do
            assert_equal "refreshed-access-token", @service.refresh_access_token!
          end
        end
      end

      assert_equal "old-refresh-token", @connection.reload.refresh_token
    end
  end
end
