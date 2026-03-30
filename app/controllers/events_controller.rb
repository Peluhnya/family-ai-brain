class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family

  def create
    @event = @family.events.new(event_params)

    if @event.save
      redirect_to family_path(@family), notice: "Event was successfully created."
    else
      prepare_family_state
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def event_params
    params.expect(event: %i[title start_time end_time location external_id source])
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
    @events = @family.events.upcoming_first.limit(10)
    @event_form = @event
    @tasks = @family.tasks.open_first.limit(10)
    @task_form = @family.tasks.new(status: "pending", priority: 3)
    @automation_rules = @family.automation_rules.active_first.limit(8)
    @automation_rule_form = @family.automation_rules.new(active: true, template_key: "daily_ai_note")
  end
end
