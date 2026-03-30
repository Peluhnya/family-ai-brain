class LifeLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family

  def create
    @life_log = @family.life_logs.new(life_log_params)
    @life_log.embedding = FamilyBrain::EmbeddingService.embed([@life_log.event_type, @life_log.summary, @life_log.raw_text].compact.join("\n"), account: @family.account)

    if @life_log.save
      FamilyBrain::KnowledgeSyncService.new(
        family: @family,
        text: [@life_log.summary, @life_log.raw_text].compact.join("\n"),
        source: "life_log:auto"
      ).call

      redirect_to family_path(@family), notice: "Life log was successfully created."
    else
      prepare_family_state
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def life_log_params
    params.expect(life_log: %i[event_type summary raw_text importance happened_at])
  end

  def prepare_family_state
    @account = @family.account
    @families = @account.families.includes(family_members: :member_users).order(:name)
    @family_member_form = @family.family_members.new
    linked_ids = @account.families.joins(family_members: :member_users).distinct.pluck("member_users.user_id")
    @available_users = User.where(id: linked_ids + [current_user.id]).or(User.where(email: current_user.email)).order(:email)
    @ai_interactions = @family.ai_interactions.includes(:user).order(:created_at)
    @ai_interaction = @family.ai_interactions.new
    @life_logs = @family.life_logs.priority_first.limit(8)
    @life_log_form = @life_log
    @family_knowledge_items = @family.family_knowledge.priority_first.limit(8)
    @family_knowledge_form = @family.family_knowledge.new(confidence: 0.8, source: "manual")
    @documents = @family.documents.recent_first.limit(10)
    @document_form = @family.documents.new
    @events = @family.events.upcoming_first.limit(10)
    @event_form = @family.events.new(
      start_time: Time.current.change(min: 0) + 1.hour,
      end_time: Time.current.change(min: 0) + 2.hours,
      source: "manual"
    )
    @calendar_connections = @family.calendar_connections.active_first.limit(10)
    @calendar_connection_form = @family.calendar_connections.new(provider: "google_calendar", active: true)
    @reminders = @family.reminders.upcoming_first.limit(10)
    @reminder_form = @family.reminders.new(trigger_at: Time.current.change(min: 0) + 1.hour, channel: "app", status: "pending")
    @tasks = @family.tasks.open_first.limit(10)
    @task_form = @family.tasks.new(status: "pending", priority: 3)
    @automation_rules = @family.automation_rules.active_first.limit(8)
    @automation_rule_form = @family.automation_rules.new(active: true, template_key: "daily_ai_note")
  end
end
