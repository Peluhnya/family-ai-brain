module FamilyPageContext
  extend ActiveSupport::Concern

  FAMILY_TABS = %w[
    chat documents reminders connections events tasks automations knowledge logs members
  ].freeze

  included do
    helper_method :active_family_tab
  end

  private

  def active_family_tab
    @active_family_tab ||= normalize_family_tab(params[:tab].presence || params[:return_tab].presence)
  end

  def normalize_family_tab(value)
    tab = value.to_s
    FAMILY_TABS.include?(tab) ? tab : "chat"
  end

  def prepare_family_page(family:, active_tab: nil, form_overrides: {})
    @family = family
    @account = @family.account
    @families = @account.families.includes(family_members: :member_users).order(:name)
    @active_family_tab = normalize_family_tab(active_tab || active_family_tab)

    load_family_tab_data(@active_family_tab, form_overrides.transform_keys(&:to_sym))
  end

  def load_family_tab_data(tab, form_overrides)
    case tab
    when "chat"
      @ai_interactions = @family.ai_interactions.includes(:user).order(:created_at)
      @ai_interaction = form_overrides.fetch(:ai_interaction, @family.ai_interactions.new)
    when "documents"
      @documents = @family.documents.recent_first.limit(20)
      @document_form = form_overrides.fetch(:document_form, @family.documents.new)
    when "reminders"
      @reminders = @family.reminders.upcoming_first.limit(20)
      @reminder_form = form_overrides.fetch(
        :reminder_form,
        @family.reminders.new(trigger_at: Time.current.change(min: 0) + 1.hour, channel: "app", status: "pending")
      )
    when "connections"
      @calendar_connections = @family.calendar_connections.active_first.limit(20)
      @calendar_connection_form = form_overrides.fetch(
        :calendar_connection_form,
        @family.calendar_connections.new(provider: "google_calendar", active: true)
      )
    when "events"
      @events = @family.events.upcoming_first.limit(20)
      @event_form = form_overrides.fetch(
        :event_form,
        @family.events.new(
          start_time: Time.current.change(min: 0) + 1.hour,
          end_time: Time.current.change(min: 0) + 2.hours,
          source: "manual"
        )
      )
    when "tasks"
      @tasks = @family.tasks.open_first.limit(20)
      @task_form = form_overrides.fetch(:task_form, @family.tasks.new(status: "pending", priority: 3))
    when "automations"
      @automation_rules = @family.automation_rules.active_first.limit(20)
      @automation_rule_form = form_overrides.fetch(
        :automation_rule_form,
        @family.automation_rules.new(active: true, template_key: "daily_ai_note")
      )
    when "knowledge"
      @family_knowledge_items = @family.family_knowledge.priority_first.limit(20)
      @family_knowledge_form = form_overrides.fetch(
        :family_knowledge_form,
        @family.family_knowledge.new(confidence: 0.8, source: "manual")
      )
    when "logs"
      @life_logs = @family.life_logs.priority_first.limit(20)
      @life_log_form = form_overrides.fetch(
        :life_log_form,
        @family.life_logs.new(happened_at: Time.current, importance: 0.7, event_type: "routine")
      )
    when "members"
      @available_users = available_users_for(@account)
      @family_member_form = form_overrides.fetch(:family_member_form, @family.family_members.new)
    end
  end

  def available_users_for(account)
    linked_ids = account.families.joins(family_members: :member_users).distinct.pluck("member_users.user_id")
    User.where(id: linked_ids + [current_user.id]).or(User.where(email: current_user.email)).order(:email)
  end

  def family_tab_redirect_path(family, tab = nil)
    target_tab = normalize_family_tab(tab || active_family_tab)
    target_tab == "chat" ? family_path(family) : tab_family_path(family, tab: target_tab)
  end
end
