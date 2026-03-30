class AiInteractionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family

  def create
    user_message = @family.ai_interactions.create!(
      user: current_user,
      role: "user",
      content: ai_interaction_params[:content],
      model: "human"
    )

    result = FamilyBrain::ChatService.new(family: @family, user: current_user, message: user_message).call

    assistant_message = @family.ai_interactions.create!(
      role: "assistant",
      content: result[:content],
      model: result[:model],
      tokens: result[:tokens]
    )

    trigger_chat_keyword_automations(user_message)

    FamilyBrain::KnowledgeSyncService.new(
      family: @family,
      text: [user_message.content, assistant_message.content].join("\n\n"),
      source: "chat:auto"
    ).call

    FamilyBrain::TaskSyncService.new(
      family: @family,
      text: [user_message.content, assistant_message.content].join("\n\n")
    ).call

    FamilyBrain::EventSyncService.new(
      family: @family,
      text: [user_message.content, assistant_message.content].join("\n\n")
    ).call

    FamilyBrain::ReminderSyncService.new(
      family: @family,
      text: [user_message.content, assistant_message.content].join("\n\n")
    ).call

    redirect_to family_path(@family)
  rescue ActiveRecord::RecordInvalid
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
    redirect_to family_path(@family), alert: "Message could not be sent."
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def ai_interaction_params
    params.expect(ai_interaction: [:content])
  end

  def trigger_chat_keyword_automations(user_message)
    @family.automation_rules.where(active: true, trigger_type: "chat_keyword").find_each do |rule|
      keyword = rule.trigger_config["keyword"].to_s.strip.downcase
      next if keyword.blank?
      next unless user_message.content.to_s.downcase.include?(keyword)

      AutomationRuleExecutionJob.perform_later(rule.id, { keyword: keyword, message: user_message.content })
    end
  end
end
