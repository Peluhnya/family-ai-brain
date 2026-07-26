require "test_helper"

module CalendarSync
  class OutlookOauthServiceTest < ActiveSupport::TestCase
    setup do
      @connection = families(:one).calendar_connections.create!(provider: "outlook_calendar", access_token: "old", refresh_token: "refresh")
      @service = OutlookOauthService.new(connection: @connection, redirect_uri: "https://app.example.com/calendar_connections/outlook_callback")
    end

    test "builds Microsoft authorization URL for offline read-only calendar access" do
      url = URI(@service.stub(:client_id, "client-id") { @service.authorization_url(state: "secure-state") })
      query = Rack::Utils.parse_query(url.query)

      assert_equal OutlookOauthService::AUTHORIZE_URL, "#{url.scheme}://#{url.host}#{url.path}"
      assert_equal "client-id", query["client_id"]
      assert_equal OutlookOauthService::SCOPE, query["scope"]
      assert_equal "query", query["response_mode"]
      assert_equal "secure-state", query["state"]
    end

    test "authorization does not retain another Microsoft account refresh token" do
      @service.stub(:post_form, { "access_token" => "new" }) do
        @service.stub(:client_id, "id") do
          @service.stub(:client_secret, "secret") { @service.exchange_code!(code: "code") }
        end
      end

      assert_equal "new", @connection.reload.access_token
      assert_nil @connection.refresh_token
    end
  end
end
