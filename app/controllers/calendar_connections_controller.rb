class CalendarConnectionsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family, only: %i[create update destroy]
  before_action :set_connection, only: %i[sync authorize_google select_google_calendar update_google_calendar]
  before_action :set_nested_connection, only: %i[update destroy]

  def create
    @calendar_connection = @family.calendar_connections.new(calendar_connection_params)

    if @calendar_connection.save
      respond_with_family_tab_success(family: @family, active_tab: "connections", notice: "Calendar connection was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "connections", form_overrides: { calendar_connection_form: @calendar_connection }, status: :unprocessable_entity)
    end
  end

  def update
    if @calendar_connection.update(calendar_connection_params)
      respond_with_family_tab_success(family: @family, active_tab: "connections", notice: "Calendar connection was successfully updated.")
    else
      render_family_tab_page(family: @family, active_tab: "connections", form_overrides: { calendar_connection_form: @calendar_connection }, status: :unprocessable_entity)
    end
  end

  def destroy
    @calendar_connection.destroy!
    respond_with_family_tab_success(family: @family, active_tab: "connections", notice: "Calendar connection was successfully removed.")
  end

  def authorize_google
    unless @calendar_connection.google_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Google OAuth is available only for Google Calendar connections."
    end

    state = SecureRandom.hex(24)
    session[:google_calendar_oauth_state] = state
    session[:google_calendar_connection_id] = @calendar_connection.id

    redirect_to google_oauth_service(@calendar_connection).authorization_url(state:), allow_other_host: true
  end

  def google_callback
    state = params[:state].to_s
    expected_state = session.delete(:google_calendar_oauth_state).to_s
    connection_id = session.delete(:google_calendar_connection_id)

    return redirect_to root_path, alert: "Google authorization state mismatch." if state.blank? || expected_state.blank? || state != expected_state
    return redirect_to root_path, alert: "Missing Google calendar connection context." if connection_id.blank?

    connection = CalendarConnection.joins(family: :account).where(accounts: { user_id: current_user.id }).find(connection_id)
    google_oauth_service(connection).exchange_code!(code: params.expect(:code))

    redirect_to select_google_calendar_calendar_connection_path(connection), notice: "Google Calendar was successfully connected. Choose which calendar to sync."
  rescue KeyError => e
    redirect_to root_path, alert: "Google OAuth is not configured: #{e.message}"
  rescue StandardError => e
    fallback_family = connection&.family || Family.joins(:account).where(accounts: { user_id: current_user.id }).first
    redirect_to family_tab_redirect_path(fallback_family, "connections"), alert: "Google authorization failed: #{e.message}"
  end

  def select_google_calendar
    unless @calendar_connection.google_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Calendar selection is available only for Google Calendar connections."
    end

    @google_calendars = CalendarSync::GoogleCalendarListService.new(connection: @calendar_connection).call
  rescue StandardError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Could not load Google calendars: #{e.message}"
  end

  def update_google_calendar
    unless @calendar_connection.google_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Calendar selection is available only for Google Calendar connections."
    end

    calendar_id = params.expect(:remote_calendar_id)
    calendars = CalendarSync::GoogleCalendarListService.new(connection: @calendar_connection).call
    selected_calendar = calendars.find { |calendar| calendar[:id] == calendar_id }
    return redirect_to select_google_calendar_calendar_connection_path(@calendar_connection), alert: "Selected Google calendar was not found." unless selected_calendar

    @calendar_connection.update!(
      remote_calendar_id: selected_calendar[:id],
      display_name: selected_calendar[:summary],
      settings: @calendar_connection.settings.merge(
        "provider_timezone" => selected_calendar[:time_zone].presence || @calendar_connection.settings["provider_timezone"],
        "google_access_role" => selected_calendar[:access_role],
        "google_primary" => selected_calendar[:primary]
      )
    )

    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), notice: "Google calendar was selected for sync."
  rescue StandardError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Could not save selected Google calendar: #{e.message}"
  end

  def sync
    result = CalendarSync::ConnectionSyncService.new(connection: @calendar_connection).call
    message = "#{result[:imported]} event(s) synced."

    if result[:error].present?
      redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: result[:error]
    else
      redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), notice: message
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def set_connection
    @calendar_connection = CalendarConnection.joins(family: :account)
      .where(accounts: { user_id: current_user.id })
      .find(params.expect(:id))
  end

  def set_nested_connection
    @calendar_connection = @family.calendar_connections.find(params.expect(:id))
  end

  def calendar_connection_params
    params.expect(calendar_connection: %i[provider display_name remote_calendar_id access_token refresh_token active]).merge(settings: connection_settings)
  end

  def connection_settings
    public_url = params.dig(:calendar_connection, :public_url).to_s.strip
    provider_timezone = params.dig(:calendar_connection, :provider_timezone).to_s.strip

    {}.tap do |settings|
      settings["public_url"] = public_url if public_url.present?
      settings["provider_timezone"] = provider_timezone if provider_timezone.present?
    end
  end

  def google_oauth_service(connection = @calendar_connection)
    CalendarSync::GoogleOauthService.new(connection:, redirect_uri: google_callback_calendar_connections_url)
  end
end
