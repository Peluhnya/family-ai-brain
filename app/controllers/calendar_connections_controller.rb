class CalendarConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family, only: :create
  before_action :set_connection, only: %i[sync authorize_google select_google_calendar update_google_calendar]

  def create
    @calendar_connection = @family.calendar_connections.new(calendar_connection_params)

    if @calendar_connection.save
      redirect_to family_path(@family), notice: "Calendar connection was successfully created."
    else
      prepare_family_state
      render "families/show", status: :unprocessable_entity
    end
  end

  def authorize_google
    unless @calendar_connection.google_calendar?
      return redirect_to family_path(@calendar_connection.family), alert: "Google OAuth is available only for Google Calendar connections."
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
    redirect_to family_path(connection&.family || Family.joins(:account).where(accounts: { user_id: current_user.id }).first), alert: "Google authorization failed: #{e.message}"
  end

  def select_google_calendar
    unless @calendar_connection.google_calendar?
      return redirect_to family_path(@calendar_connection.family), alert: "Calendar selection is available only for Google Calendar connections."
    end

    @google_calendars = CalendarSync::GoogleCalendarListService.new(connection: @calendar_connection).call
  rescue StandardError => e
    redirect_to family_path(@calendar_connection.family), alert: "Could not load Google calendars: #{e.message}"
  end

  def update_google_calendar
    unless @calendar_connection.google_calendar?
      return redirect_to family_path(@calendar_connection.family), alert: "Calendar selection is available only for Google Calendar connections."
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

    redirect_to family_path(@calendar_connection.family), notice: "Google calendar was selected for sync."
  rescue StandardError => e
    redirect_to family_path(@calendar_connection.family), alert: "Could not save selected Google calendar: #{e.message}"
  end

  def sync
    result = CalendarSync::ConnectionSyncService.new(connection: @calendar_connection).call
    message = "#{result[:imported]} event(s) synced."

    if result[:error].present?
      redirect_to family_path(@calendar_connection.family), alert: result[:error]
    else
      redirect_to family_path(@calendar_connection.family), notice: message
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

  def prepare_family_state
    @account = @family.account
    @families = @account.families.includes(family_members: :member_users).order(:name)
    linked_ids = @account.families.joins(family_members: :member_users).distinct.pluck("member_users.user_id")
    @available_users = User.where(id: linked_ids + [current_user.id]).or(User.where(email: current_user.email)).order(:email)
    @family_member_form = @family.family_members.new
    @ai_interactions = @family.ai_interactions.includes(:user).order(:created_at)
    @ai_interaction = @family.ai_interactions.new
    @life_logs = @family.life_logs.priority_first.limit(8)
    @life_log_form = @family.life_logs.new(happened_at: Time.current, importance: 0.7, event_type: "routine")
    @family_knowledge_items = @family.family_knowledge.priority_first.limit(8)
    @family_knowledge_form = @family.family_knowledge.new(confidence: 0.8, source: "manual")
    @documents = @family.documents.recent_first.limit(10)
    @document_form = @family.documents.new
    @events = @family.events.upcoming_first.limit(10)
    @event_form = @family.events.new(start_time: Time.current.change(min: 0) + 1.hour, end_time: Time.current.change(min: 0) + 2.hours, source: "manual")
    @calendar_connections = @family.calendar_connections.active_first.limit(10)
    @calendar_connection_form = @calendar_connection
    @reminders = @family.reminders.upcoming_first.limit(10)
    @reminder_form = @family.reminders.new(trigger_at: Time.current.change(min: 0) + 1.hour, channel: "app", status: "pending")
    @tasks = @family.tasks.open_first.limit(10)
    @task_form = @family.tasks.new(status: "pending", priority: 3)
    @automation_rules = @family.automation_rules.active_first.limit(8)
    @automation_rule_form = @family.automation_rules.new(active: true, template_key: "daily_ai_note")
  end

  def google_oauth_service(connection = @calendar_connection)
    CalendarSync::GoogleOauthService.new(connection:, redirect_uri: google_callback_calendar_connections_url)
  end
end
