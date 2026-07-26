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

  test "saves and syncs only selected Google calendars" do
    connection = @family.calendar_connections.create!(
      provider: "google_calendar",
      remote_calendar_id: "all",
      access_token: "test-token"
    )
    calendars = [
      { id: "primary@example.com", summary: "Особистий", time_zone: "Europe/Kyiv" },
      { id: "family@example.com", summary: "Сімейний", time_zone: "Europe/Kyiv" },
      { id: "work@example.com", summary: "Робота", time_zone: "Europe/Kyiv" }
    ]
    list_service = Object.new
    list_service.define_singleton_method(:call) { calendars }
    sync_service = Object.new
    sync_service.define_singleton_method(:call) { { imported: 4, error: nil } }

    CalendarSync::GoogleCalendarListService.stub(:new, list_service) do
      CalendarSync::ConnectionSyncService.stub(:new, sync_service) do
        post update_google_calendar_calendar_connection_url(connection), params: {
          google_calendar_ids: [ "primary@example.com", "family@example.com" ]
        }
      end
    end

    assert_redirected_to tab_family_url(@family, tab: "calendar")
    assert_equal [ "primary@example.com", "family@example.com" ], connection.reload.settings["google_calendar_ids"]
    assert_equal "Google Calendar (2)", connection.display_name
  end

  test "removes imported events after their Google calendar is deselected" do
    connection = @family.calendar_connections.create!(
      provider: "google_calendar",
      remote_calendar_id: "selected",
      access_token: "test-token",
      settings: { "google_calendar_ids" => [ "primary@example.com", "shared@example.com" ] }
    )
    retained_event = @family.events.create!(
      title: "Особиста подія", start_time: Time.zone.parse("2026-08-01 10:00"),
      external_id: "primary@example.com:event-1", source: "google_calendar"
    )
    removed_event = @family.events.create!(
      title: "Спільна подія", start_time: Time.zone.parse("2026-08-02 10:00"),
      external_id: "shared@example.com:event-2", source: "google_calendar"
    )
    calendars = [
      { id: "primary@example.com", summary: "Особистий" },
      { id: "shared@example.com", summary: "Спільний" }
    ]
    list_service = Object.new
    list_service.define_singleton_method(:call) { calendars }
    sync_service = Object.new
    sync_service.define_singleton_method(:call) { { imported: 1, error: nil } }

    CalendarSync::GoogleCalendarListService.stub(:new, list_service) do
      CalendarSync::ConnectionSyncService.stub(:new, sync_service) do
        post update_google_calendar_calendar_connection_url(connection), params: {
          google_calendar_ids: [ "primary@example.com" ]
        }
      end
    end

    assert_predicate retained_event.reload, :persisted?
    assert_not Event.exists?(removed_event.id)
  end

  test "does not allow saving an empty Google calendar selection" do
    connection = @family.calendar_connections.create!(provider: "google_calendar", access_token: "test-token")
    list_service = Object.new
    list_service.define_singleton_method(:call) { [ { id: "primary@example.com", summary: "Особистий" } ] }

    CalendarSync::GoogleCalendarListService.stub(:new, list_service) do
      post update_google_calendar_calendar_connection_url(connection)
    end

    assert_redirected_to select_google_calendar_calendar_connection_url(connection)
    assert_equal "Оберіть щонайменше один календар.", flash[:alert]
    assert_nil connection.reload.settings["google_calendar_ids"]
  end
  test "connects Apple credentials and redirects to calendar selection" do
    list_service = Object.new
    list_service.define_singleton_method(:call) { [ { id: "https://caldav.test/family/", summary: "Family" } ] }

    assert_difference -> { @family.calendar_connections.count }, 1 do
      CalendarSync::AppleCalendarListService.stub(:new, list_service) do
        post family_connect_apple_calendar_url(@family), params: { apple_id: "owner@icloud.com", app_password: "abcd-efgh-ijkl-mnop" }
      end
    end

    connection = @family.calendar_connections.order(:created_at).last
    assert_redirected_to select_apple_calendar_calendar_connection_url(connection)
    assert_equal "apple_calendar", connection.provider
    assert_equal "owner@icloud.com", connection.settings["apple_id"]
    assert_equal "abcd-efgh-ijkl-mnop", connection.access_token
  end

  test "does not save an Apple connection when credentials are rejected" do
    list_service = Object.new
    list_service.define_singleton_method(:call) { raise "invalid credentials" }

    assert_no_difference -> { @family.calendar_connections.count } do
      CalendarSync::AppleCalendarListService.stub(:new, list_service) do
        post family_connect_apple_calendar_url(@family), params: { apple_id: "owner@icloud.com", app_password: "wrong" }
      end
    end

    assert_redirected_to tab_family_url(@family, tab: "connections")
    assert_match "invalid credentials", flash[:alert]
  end
end
