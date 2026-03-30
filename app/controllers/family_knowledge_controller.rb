class FamilyKnowledgeController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family

  def create
    @knowledge = @family.family_knowledge.new(family_knowledge_params)
    @knowledge.embedding = FamilyBrain::EmbeddingService.embed([@knowledge.key, @knowledge.value].compact.join(": "), account: @family.account)

    if @knowledge.save
      redirect_to family_path(@family), notice: "Family knowledge was successfully created."
    else
      prepare_family_state
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def family_knowledge_params
    params.expect(family_knowledge: %i[key value source confidence])
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
    @family_knowledge_form = @knowledge
    @events = @family.events.upcoming_first.limit(10)
    @event_form = @family.events.new(
      start_time: Time.current.change(min: 0) + 1.hour,
      end_time: Time.current.change(min: 0) + 2.hours,
      source: "manual"
    )
    @tasks = @family.tasks.open_first.limit(10)
    @task_form = @family.tasks.new(status: "pending", priority: 3)
    @automation_rules = @family.automation_rules.active_first.limit(8)
    @automation_rule_form = @family.automation_rules.new(active: true, template_key: "daily_ai_note")
  end
end
