class CalendarConnectionsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family, only: %i[create update destroy connect_google connect_outlook connect_apple]
  before_action :set_connection, only: %i[sync authorize_google select_google_calendar update_google_calendar authorize_outlook select_outlook_calendar update_outlook_calendar select_apple_calendar update_apple_calendar]
  before_action :set_nested_connection, only: %i[update destroy]

  def create
    @calendar_connection = @family.calendar_connections.new(calendar_connection_params)

    if @calendar_connection.save
      respond_with_family_tab_success(family: @family, active_tab: "connections", notice: "Calendar connection was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "connections", form_overrides: { calendar_connection_form: @calendar_connection }, status: :unprocessable_entity)
    end
  end

  def connect_google
    connection = @family.calendar_connections.create!(provider: "google_calendar", active: true)
    start_google_authorization(connection)
  rescue KeyError => e
    connection&.destroy
    redirect_to family_tab_redirect_path(@family, "connections"), alert: "Google OAuth is not configured: #{e.message}"
  end

  def connect_outlook
    connection = @family.calendar_connections.create!(provider: "outlook_calendar", active: true)
    start_outlook_authorization(connection)
  rescue KeyError => e
    connection&.destroy
    redirect_to family_tab_redirect_path(@family, "connections"), alert: "Outlook OAuth is not configured: #{e.message}"
  end

  def connect_apple
    apple_id = params[:apple_id].to_s.strip
    app_password = params[:app_password].to_s.strip
    if apple_id.blank? || app_password.blank?
      return redirect_to family_tab_redirect_path(@family, "connections"), alert: "Вкажіть Apple ID та пароль програми."
    end

    connection = @family.calendar_connections.create!(
      provider: "apple_calendar", display_name: "Apple Calendar", access_token: app_password,
      active: true, settings: { "apple_id" => apple_id }
    )
    CalendarSync::AppleCalendarListService.new(connection:).call
    redirect_to select_apple_calendar_calendar_connection_path(connection), notice: "Apple Calendar підключено. Оберіть календарі для синхронізації."
  rescue StandardError => e
    connection&.destroy
    redirect_to family_tab_redirect_path(@family, "connections"), alert: "Не вдалося підключити Apple Calendar: #{e.message}"
  end

  def select_apple_calendar
    unless @calendar_connection.apple_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Calendar selection is available only for Apple Calendar connections."
    end

    @apple_calendars = CalendarSync::AppleCalendarListService.new(connection: @calendar_connection).call
    @selected_apple_calendar_ids = @calendar_connection.settings.fetch("apple_calendar_ids", [])
  rescue StandardError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Could not load Apple calendars: #{e.message}"
  end

  def update_apple_calendar
    calendars = CalendarSync::AppleCalendarListService.new(connection: @calendar_connection).call
    requested_ids = Array(params[:apple_calendar_ids]).compact_blank.uniq
    available_ids = calendars.pluck(:id)
    selected_calendars = calendars.select { |calendar| requested_ids.include?(calendar[:id]) }
    return redirect_to select_apple_calendar_calendar_connection_path(@calendar_connection), alert: "Оберіть щонайменше один календар." if requested_ids.empty?
    unless requested_ids.all? { |calendar_id| available_ids.include?(calendar_id) }
      return redirect_to select_apple_calendar_calendar_connection_path(@calendar_connection), alert: "Один або декілька вибраних календарів недоступні."
    end

    @calendar_connection.update!(remote_calendar_id: requested_ids.sort.join(","), display_name: "Apple Calendar (#{selected_calendars.size})",
      sync_cursor: nil, settings: @calendar_connection.settings.merge("apple_calendar_ids" => requested_ids,
        "apple_calendar_names" => selected_calendars.to_h { |calendar| [ calendar[:id], calendar[:summary] ] }))
    remove_unselected_events!(provider: "apple_calendar", calendar_ids: available_ids - requested_ids, hashed_prefixes: true)
    result = CalendarSync::ConnectionSyncService.new(connection: @calendar_connection).call
    if result[:error].present?
      redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Налаштування збережено, але синхронізація не вдалася: #{result[:error]}"
    else
      redirect_to family_tab_redirect_path(@calendar_connection.family, "calendar"), notice: "Вибрані календарі збережено. Синхронізовано подій: #{result[:imported]}."
    end
  rescue StandardError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Could not save selected Apple calendar: #{e.message}"
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

    start_google_authorization(@calendar_connection)
  rescue KeyError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Google OAuth is not configured: #{e.message}"
  end

  def google_callback
    state = params[:state].to_s
    expected_state = session.delete(:google_calendar_oauth_state).to_s
    connection_id = session.delete(:google_calendar_connection_id)

    return redirect_to root_path, alert: "Google authorization state mismatch." if state.blank? || expected_state.blank? || state != expected_state
    return redirect_to root_path, alert: "Missing Google calendar connection context." if connection_id.blank?

    connection = CalendarConnection.joins(family: :account).where(accounts: { user_id: current_user.id }).find(connection_id)
    google_oauth_service(connection).exchange_code!(code: params.expect(:code))
    redirect_to select_google_calendar_calendar_connection_path(connection), notice: "Google Calendar підключено. Оберіть календарі для синхронізації."
  rescue KeyError => e
    redirect_to root_path, alert: "Google OAuth is not configured: #{e.message}"
  rescue StandardError => e
    fallback_family = connection&.family || Family.joins(:account).where(accounts: { user_id: current_user.id }).first
    redirect_to family_tab_redirect_path(fallback_family, "connections"), alert: "Google authorization failed: #{e.message}"
  end

  def authorize_outlook
    unless @calendar_connection.outlook_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Microsoft OAuth is available only for Outlook Calendar connections."
    end

    start_outlook_authorization(@calendar_connection)
  rescue KeyError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Outlook OAuth is not configured: #{e.message}"
  end

  def outlook_callback
    state = params[:state].to_s
    expected_state = session.delete(:outlook_calendar_oauth_state).to_s
    connection_id = session.delete(:outlook_calendar_connection_id)
    return redirect_to root_path, alert: "Outlook authorization state mismatch." if state.blank? || expected_state.blank? || state != expected_state
    return redirect_to root_path, alert: "Missing Outlook calendar connection context." if connection_id.blank?

    connection = CalendarConnection.joins(family: :account).where(accounts: { user_id: current_user.id }).find(connection_id)
    outlook_oauth_service(connection).exchange_code!(code: params.expect(:code))
    redirect_to select_outlook_calendar_calendar_connection_path(connection), notice: "Outlook Calendar підключено. Оберіть календарі для синхронізації."
  rescue KeyError => e
    redirect_to root_path, alert: "Outlook OAuth is not configured: #{e.message}"
  rescue StandardError => e
    fallback_family = connection&.family || Family.joins(:account).where(accounts: { user_id: current_user.id }).first
    redirect_to family_tab_redirect_path(fallback_family, "connections"), alert: "Outlook authorization failed: #{e.message}"
  end

  def select_outlook_calendar
    unless @calendar_connection.outlook_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Calendar selection is available only for Outlook Calendar connections."
    end

    @outlook_calendars = CalendarSync::OutlookCalendarListService.new(connection: @calendar_connection).call
    @selected_outlook_calendar_ids = @calendar_connection.settings.fetch("outlook_calendar_ids", [])
  rescue StandardError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Could not load Outlook calendars: #{e.message}"
  end

  def update_outlook_calendar
    unless @calendar_connection.outlook_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Calendar selection is available only for Outlook Calendar connections."
    end

    calendars = CalendarSync::OutlookCalendarListService.new(connection: @calendar_connection).call
    requested_ids = Array(params[:outlook_calendar_ids]).compact_blank.uniq
    available_ids = calendars.pluck(:id)
    selected_calendars = calendars.select { |calendar| requested_ids.include?(calendar[:id]) }
    return redirect_to select_outlook_calendar_calendar_connection_path(@calendar_connection), alert: "Оберіть щонайменше один календар." if requested_ids.empty?
    unless requested_ids.all? { |calendar_id| available_ids.include?(calendar_id) }
      return redirect_to select_outlook_calendar_calendar_connection_path(@calendar_connection), alert: "Один або декілька вибраних календарів недоступні."
    end

    @calendar_connection.update!(remote_calendar_id: requested_ids.sort.join(","), display_name: "Outlook Calendar (#{selected_calendars.size})",
      sync_cursor: nil, settings: @calendar_connection.settings.merge("outlook_calendar_ids" => requested_ids,
        "outlook_calendar_names" => selected_calendars.to_h { |calendar| [ calendar[:id], calendar[:summary] ] }))
    remove_unselected_events!(provider: "outlook_calendar", calendar_ids: available_ids - requested_ids)
    result = CalendarSync::ConnectionSyncService.new(connection: @calendar_connection).call
    if result[:error].present?
      redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Налаштування збережено, але синхронізація не вдалася: #{result[:error]}"
    else
      redirect_to family_tab_redirect_path(@calendar_connection.family, "calendar"), notice: "Вибрані календарі збережено. Синхронізовано подій: #{result[:imported]}."
    end
  rescue StandardError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Could not save selected Outlook calendar: #{e.message}"
  end

  def select_google_calendar
    unless @calendar_connection.google_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Calendar selection is available only for Google Calendar connections."
    end

    @google_calendars = CalendarSync::GoogleCalendarListService.new(connection: @calendar_connection).call
    @selected_google_calendar_ids = @calendar_connection.settings.fetch("google_calendar_ids", [])
  rescue StandardError => e
    redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Could not load Google calendars: #{e.message}"
  end

  def update_google_calendar
    unless @calendar_connection.google_calendar?
      return redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Calendar selection is available only for Google Calendar connections."
    end

    calendars = CalendarSync::GoogleCalendarListService.new(connection: @calendar_connection).call
    requested_ids = Array(params[:google_calendar_ids]).compact_blank.uniq
    available_ids = calendars.pluck(:id)
    selected_calendars = calendars.select { |calendar| requested_ids.include?(calendar[:id]) }

    if requested_ids.empty?
      return redirect_to select_google_calendar_calendar_connection_path(@calendar_connection), alert: "Оберіть щонайменше один календар."
    end
    unless requested_ids.all? { |calendar_id| available_ids.include?(calendar_id) }
      return redirect_to select_google_calendar_calendar_connection_path(@calendar_connection), alert: "Один або декілька вибраних календарів недоступні."
    end

    @calendar_connection.update!(
      remote_calendar_id: requested_ids.sort.join(","),
      display_name: "Google Calendar (#{selected_calendars.size})",
      sync_cursor: nil,
      settings: @calendar_connection.settings.merge(
        "google_calendar_ids" => requested_ids,
        "google_calendar_names" => selected_calendars.to_h { |calendar| [ calendar[:id], calendar[:summary] ] }
      )
    )
    remove_unselected_google_events!(available_ids - requested_ids)
    result = CalendarSync::ConnectionSyncService.new(connection: @calendar_connection).call

    if result[:error].present?
      redirect_to family_tab_redirect_path(@calendar_connection.family, "connections"), alert: "Налаштування збережено, але синхронізація не вдалася: #{result[:error]}"
    else
      redirect_to family_tab_redirect_path(@calendar_connection.family, "calendar"), notice: "Вибрані календарі збережено. Синхронізовано подій: #{result[:imported]}."
    end
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

  def remove_unselected_google_events!(calendar_ids)
    remove_unselected_events!(provider: "google_calendar", calendar_ids:)
  end

  def remove_unselected_events!(provider:, calendar_ids:, hashed_prefixes: false)
    prefixes = calendar_ids.map { |calendar_id| "#{hashed_prefixes ? Digest::SHA256.hexdigest(calendar_id) : calendar_id}:" }
    return if prefixes.empty?

    @calendar_connection.events.where(source_key: provider).find_each do |event|
      event.destroy! if prefixes.any? { |prefix| event.external_id.to_s.start_with?(prefix) }
    end
  end

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

  def outlook_oauth_service(connection = @calendar_connection)
    CalendarSync::OutlookOauthService.new(connection:, redirect_uri: outlook_callback_calendar_connections_url)
  end

  def start_google_authorization(connection)
    state = SecureRandom.hex(24)
    authorization_url = google_oauth_service(connection).authorization_url(state:)
    session[:google_calendar_oauth_state] = state
    session[:google_calendar_connection_id] = connection.id

    redirect_to authorization_url, allow_other_host: true
  end


  def start_outlook_authorization(connection)
    state = SecureRandom.hex(24)
    authorization_url = outlook_oauth_service(connection).authorization_url(state:)
    session[:outlook_calendar_oauth_state] = state
    session[:outlook_calendar_connection_id] = connection.id
    redirect_to authorization_url, allow_other_host: true
  end
end
