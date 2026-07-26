module FamilyPageContext
  extend ActiveSupport::Concern

  FAMILY_TABS = %w[
    chat calendar documents reminders connections events tasks automations knowledge logs ai_logs members
  ].freeze
  AI_LOG_PAGE_SIZE = 10

  included do
    helper_method :active_family_tab, :active_execution_filter, :active_ai_log_type
  end

  private

  def active_family_tab
    @active_family_tab ||= normalize_family_tab(params[:tab].presence || params[:return_tab].presence)
  end

  def normalize_family_tab(value)
    tab = value.to_s
    return "chat" if tab == "ai_logs" && !ai_debug_ui_enabled?

    FAMILY_TABS.include?(tab) ? tab : "chat"
  end

  def active_ai_log_type
    value = params[:log_type].to_s
    %w[requests effects].include?(value) ? value : "requests"
  end

  def active_execution_filter
    value = params[:execution_filter].to_s
    %w[all chat duplicates].include?(value) ? value : "all"
  end

  def prepare_family_page(family:, active_tab: nil, form_overrides: {})
    @family = family
    @account = @family.account
    @families = @account.families.includes(family_members: :member_users).order(:name)
    @active_family_tab = normalize_family_tab(active_tab || active_family_tab)

    load_family_tab_data(@active_family_tab, form_overrides.transform_keys(&:to_sym))
  end

  def render_family_tab_page(family:, active_tab:, form_overrides: {}, status: :ok)
    prepare_family_page(family:, active_tab:, form_overrides:)

    if turbo_frame_request?
      render partial: "families/tab_content", locals: { family: @family, active_tab: @active_family_tab }, status: status
    else
      render "families/show", status: status
    end
  end

  def respond_with_family_tab_success(family:, active_tab:, notice:, redirect_status: :see_other, extra_params: {})
    if turbo_frame_request?
      flash.now[:notice] = notice if notice.present?
      render_family_tab_page(family:, active_tab:, status: :ok)
    else
      redirect_to family_tab_redirect_path(family, active_tab, extra_params), notice:, status: redirect_status
    end
  end

  def load_family_tab_data(tab, form_overrides)
    case tab
    when "chat"
      @today_conversation = Conversation.find_or_build_for_family_at(family: @family)
      @conversations = @family.conversations.recent_first.limit(30).to_a
      @conversations.unshift(@today_conversation) unless @conversations.include?(@today_conversation)
      @active_conversation = if params[:conversation_id].present?
        @family.conversations.find_by(id: params[:conversation_id]) || @today_conversation
      else
        @today_conversation
      end
      load_active_conversation_messages
      @viewing_today_conversation = @active_conversation == @today_conversation
      @ai_interaction = form_overrides.fetch(:ai_interaction, @family.ai_interactions.new)
    when "calendar"
      load_calendar_data
    when "documents"
      @documents = @family.documents.recent_first.limit(20)
      @document_form = form_overrides.fetch(:document_form, selected_record(@family.documents, :edit_document_id) || @family.documents.new)
    when "reminders"
      @reminders = @family.reminders.upcoming_first.limit(20)
      @reminder_form = form_overrides.fetch(
        :reminder_form,
        selected_record(@family.reminders, :edit_reminder_id) ||
          @family.reminders.new(trigger_at: Time.current.change(min: 0) + 1.hour, channel: "app", status: "pending")
      )
      load_automation_execution_data(@reminders, "Reminder")
    when "connections"
      @calendar_connections = @family.calendar_connections.active_first.limit(20)
      @calendar_connection_form = form_overrides.fetch(
        :calendar_connection_form,
        selected_record(@family.calendar_connections, :edit_calendar_connection_id) ||
          @family.calendar_connections.new(provider: "google_calendar", active: true)
      )
    when "events"
      @events = @family.events.upcoming_or_ongoing.limit(20)
      @event_form = form_overrides.fetch(
        :event_form,
        selected_record(@family.events, :edit_event_id) ||
          @family.events.new(
            start_time: Time.current.change(min: 0) + 1.hour,
            end_time: Time.current.change(min: 0) + 2.hours,
            source: "manual"
          )
      )
      load_automation_execution_data(@events, "Event")
    when "tasks"
      @tasks = @family.tasks.open_first.limit(20)
      @task_form = form_overrides.fetch(:task_form, selected_record(@family.tasks, :edit_task_id) || @family.tasks.new(status: "pending", priority: 3))
      load_automation_execution_data(@tasks, "Task")
    when "automations"
      @automation_rules = @family.automation_rules.active_first.limit(20)
      @automation_rule_form = form_overrides.fetch(
        :automation_rule_form,
        selected_record(@family.automation_rules, :edit_automation_rule_id) ||
          @family.automation_rules.new(active: true, template_key: "daily_ai_note")
      )
      load_recent_automation_executions
    when "knowledge"
      @family_knowledge_items = @family.family_knowledge.priority_first.limit(20)
      @family_knowledge_form = form_overrides.fetch(
        :family_knowledge_form,
        selected_record(@family.family_knowledge, :edit_family_knowledge_id) ||
          @family.family_knowledge.new(confidence: 0.8, source: "manual")
      )
    when "logs"
      @life_logs = @family.life_logs.priority_first.limit(20)
      @life_log_form = form_overrides.fetch(
        :life_log_form,
        selected_record(@family.life_logs, :edit_life_log_id) ||
          @family.life_logs.new(happened_at: Time.current, importance: 0.7, event_type: "routine")
      )
    when "ai_logs"
      load_ai_log_data
    when "members"
      @available_users = available_users_for(@account)
      @family_member_form = form_overrides.fetch(:family_member_form, selected_record(@family.family_members, :edit_family_member_id) || @family.family_members.new)
    end
  end

  def load_calendar_data
    requested_month = Date.iso8601(params[:month].to_s) if params[:month].present?
    @calendar_month = (requested_month || @family.local_date).beginning_of_month
  rescue Date::Error
    @calendar_month = @family.local_date.beginning_of_month
  ensure
    @calendar_grid_start = @calendar_month.beginning_of_week(:monday)
    @calendar_grid_end = @calendar_month.end_of_month.end_of_week(:monday)
    zone = ActiveSupport::TimeZone[@family.timezone.presence] || Time.zone
    range_start = zone.local(@calendar_grid_start.year, @calendar_grid_start.month, @calendar_grid_start.day)
    range_end = zone.local(@calendar_grid_end.year, @calendar_grid_end.month, @calendar_grid_end.day).end_of_day

    @calendar_events = @family.events
      .where("start_time <= ? AND COALESCE(end_time, start_time) >= ?", range_end, range_start)
      .order(:start_time)
    @calendar_tasks = @family.tasks.where(due_at: range_start..range_end).order(:due_at)
    @calendar_reminders = @family.reminders.where(trigger_at: range_start..range_end).order(:trigger_at)
    @calendar_life_logs = @family.life_logs.where(happened_at: range_start..range_end).order(:happened_at)
  end

  def available_users_for(account)
    linked_ids = account.families.joins(family_members: :member_users).distinct.pluck("member_users.user_id")
    User.where(id: linked_ids + [ current_user.id ]).or(User.where(email: current_user.email)).order(:email)
  end

  def family_tab_redirect_path(family, tab = nil, extra_params = {})
    target_tab = normalize_family_tab(tab || active_family_tab)
    if target_tab == "chat"
      family_path(family, extra_params.presence)
    else
      tab_family_path(family, { tab: target_tab }.merge(extra_params))
    end
  end

  def load_automation_execution_data(records, entity_type)
    @automation_execution_map = {}
    @automation_execution_source_map = {}
    return unless automation_execution_tracking_available?
    return if records.blank?

    executions = @family.automation_rule_executions
      .includes(:automation_rule)
      .where(created_entity_type: entity_type, created_entity_id: records.map(&:id))
      .order(created_at: :desc)

    @automation_execution_map = executions.group_by(&:created_entity_id).transform_values(&:first)

    source_ids = executions.filter_map { |execution| execution.source_id if execution.source_type == "AiInteraction" }.uniq
    return if source_ids.empty?

    @automation_execution_source_map = @family.ai_interactions.where(id: source_ids).index_by(&:id)
  end

  def load_recent_automation_executions
    @recent_automation_executions = []
    @automation_execution_source_map = {}
    return unless automation_execution_tracking_available?

    executions = @family.automation_rule_executions
      .includes(:automation_rule)
    executions = apply_execution_filter(executions)
    @recent_automation_executions = executions.order(created_at: :desc).limit(20)

    source_ids = @recent_automation_executions.filter_map { |execution| execution.source_id if execution.source_type == "AiInteraction" }.uniq
    return if source_ids.empty?

    @automation_execution_source_map = @family.ai_interactions.where(id: source_ids).index_by(&:id)
  end

  def apply_execution_filter(scope)
    case active_execution_filter
    when "chat"
      scope.where(source_type: "AiInteraction")
    when "duplicates"
      duplicate_digests = @family.automation_rule_executions
        .where.not(context_digest: [ nil, "" ])
        .group(:automation_rule_id, :context_digest)
        .having("COUNT(*) > 1")
        .pluck(:context_digest)

      return scope.none if duplicate_digests.empty?

      scope.where(context_digest: duplicate_digests)
    else
      scope
    end
  end

  def automation_execution_tracking_available?
    AutomationRuleExecution.table_exists?
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end

  def ai_effect_tracking_available?
    AiEffect.table_exists?
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end

  def ai_debug_ui_enabled?
    Rails.env.development? || Rails.env.test?
  end

  def load_active_conversation_messages
    unless @active_conversation.persisted?
      @ai_interactions = []
      @has_older_messages = false
      @older_messages_before_id = nil
      return
    end

    page = FamilyBrain::ConversationMessagePage.new(conversation: @active_conversation)
    @ai_interactions = page.messages
    @has_older_messages = page.has_older?
    @older_messages_before_id = page.before_id
  end

  def load_ai_log_data
    request_scope = @family.ai_interactions.tracked_llm_requests
    effects_available = ai_effect_tracking_available?
    effect_scope = @family.ai_effects if effects_available

    @ai_log_summary = {
      requests_count: request_scope.count,
      total_tokens: request_scope.sum(:tokens).to_i,
      effects_count: effects_available ? effect_scope.count : 0,
      failures_count: effects_available ? effect_scope.failures.count : 0
    }

    scope = if active_ai_log_type == "effects" && effects_available
      effect_scope.includes(source_ai_interaction: :conversation).recent_first
    elsif active_ai_log_type == "effects"
      nil
    else
      request_scope.includes(:user, :conversation).order(created_at: :desc)
    end

    @ai_log_total_count = scope&.count.to_i
    @ai_log_total_pages = [ (@ai_log_total_count.to_f / AI_LOG_PAGE_SIZE).ceil, 1 ].max
    @ai_log_page = [ [ params[:page].to_i, 1 ].max, @ai_log_total_pages ].min
    @ai_log_entries = scope ? scope.offset((@ai_log_page - 1) * AI_LOG_PAGE_SIZE).limit(AI_LOG_PAGE_SIZE) : []
    @ai_log_range_start = @ai_log_total_count.zero? ? 0 : ((@ai_log_page - 1) * AI_LOG_PAGE_SIZE) + 1
    @ai_log_range_end = [ @ai_log_page * AI_LOG_PAGE_SIZE, @ai_log_total_count ].min
  end

  def selected_record(scope, param_key)
    record_id = params[param_key].presence
    return if record_id.blank?

    scope.find_by(id: record_id)
  end
end
