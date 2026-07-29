require "test_helper"

class HotwireNativeControllerTest < ActionDispatch::IntegrationTest
  test "serves a cacheable path configuration" do
    get hotwire_native_configuration_url

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match "max-age=3600", response.headers["cache-control"]

    configuration = response.parsed_body
    assert_equal true, configuration.dig("settings", "screenshots_enabled")
    assert_equal ".*", configuration.dig("rules", 0, "patterns", 0)
    assert_equal "default", configuration.dig("rules", 0, "properties", "context")
  end

  test "marks Hotwire Native requests and hides web chrome" do
    get root_url, headers: { "User-Agent" => "Family Brain/1.0 Hotwire Native iOS" }

    assert_response :success
    assert_select "body.hotwire-native[data-hotwire-native='true']"
    assert_select "header[data-hotwire-native-hide]"
  end

  test "supports the legacy Turbo Native user agent" do
    get root_url, headers: { "User-Agent" => "Turbo Native Android" }

    assert_response :success
    assert_select "body.hotwire-native[data-hotwire-native='true']"
  end

  test "does not mark regular web requests as native" do
    get root_url

    assert_response :success
    assert_select "body:not(.hotwire-native)[data-hotwire-native='false']"
  end
end
