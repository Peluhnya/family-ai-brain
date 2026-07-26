require "test_helper"

class CalendarConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "calendar-owner@example.com", password: "password123", password_confirmation: "password123")
    @account = @user.accounts.create!(name: "Calendar account", email: @user.email, active: true)
    @family = @account.families.create!(name: "Calendar family", timezone: "Europe/Kyiv", locale: "uk")
    sign_in @user
  end

  test "starts Google authorization and attaches the pending connection to the family" do
    oauth_service = Object.new
    oauth_service.define_singleton_method(:authorization_url) do |state:|
      "https://accounts.google.test/authorize?state=#{state}"
    end

    assert_difference -> { @family.calendar_connections.count }, 1 do
      CalendarSync::GoogleOauthService.stub(:new, oauth_service) do
        post family_connect_google_calendar_url(@family)
      end
    end

    assert_response :redirect
    assert_match %r{\Ahttps://accounts\.google\.test/authorize\?state=[a-f0-9]{48}\z}, response.location
    connection = @family.calendar_connections.order(:created_at).last
    assert_equal "google_calendar", connection.provider
    assert_predicate connection, :active?
  end

  test "does not leave a pending connection when Google OAuth is not configured" do
    oauth_service = Object.new
    oauth_service.define_singleton_method(:authorization_url) { |state:| raise KeyError, "GOOGLE_CLIENT_ID is missing" }

    assert_no_difference -> { @family.calendar_connections.count } do
      CalendarSync::GoogleOauthService.stub(:new, oauth_service) do
        post family_connect_google_calendar_url(@family)
      end
    end

    assert_redirected_to tab_family_url(@family, tab: "connections")
    assert_equal "Google OAuth is not configured: GOOGLE_CLIENT_ID is missing", flash[:alert]
  end

  test "cannot attach a Google connection to another user's family" do
    other_user = User.create!(email: "other-calendar-owner@example.com", password: "password123", password_confirmation: "password123")
    other_account = other_user.accounts.create!(name: "Other account", email: other_user.email, active: true)
    other_family = other_account.families.create!(name: "Other family", timezone: "UTC", locale: "uk")

    assert_no_difference -> { CalendarConnection.count } do
      post family_connect_google_calendar_url(other_family)
    end

    assert_response :not_found
  end
end
