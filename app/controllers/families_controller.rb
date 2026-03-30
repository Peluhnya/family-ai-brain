class FamiliesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account, only: %i[index new create]
  before_action :set_family, only: %i[show edit update destroy run_automation_rules]

  def index
    @families = @account.families.includes(family_members: :member_users).order(:name)
  end

  def show
    @account = @family.account
    @families = @account.families.includes(family_members: :member_users).order(:name)
    @family_member_form = @family.family_members.new
    @available_users = available_users_for(@account)
    @ai_interactions = @family.ai_interactions.includes(:user).order(:created_at)
    @ai_interaction = @family.ai_interactions.new
    @life_logs = @family.life_logs.priority_first.limit(8)
    @life_log_form = @family.life_logs.new(happened_at: Time.current, importance: 0.7, event_type: "routine")
    @family_knowledge_items = @family.family_knowledge.priority_first.limit(8)
    @family_knowledge_form = @family.family_knowledge.new(confidence: 0.8, source: "manual")
    @events = @family.events.upcoming_first.limit(10)
    @event_form = @family.events.new(
      start_time: Time.current.change(min: 0) + 1.hour,
      end_time: Time.current.change(min: 0) + 2.hours,
      source: "manual"
    )
    @tasks = @family.tasks.open_first.limit(10)
    @task_form = @family.tasks.new(status: "pending", priority: 3)
    @automation_rules = @family.automation_rules.active_first.limit(8)
    @automation_rule_form = @family.automation_rules.new(
      active: true,
      template_key: "daily_ai_note"
    )
  end

  def new
    @family = @account.families.new(timezone: "Europe/Berlin", locale: I18n.locale.to_s)
  end

  def edit
    @account = @family.account
  end

  def create
    @family = @account.families.new(family_params)

    respond_to do |format|
      if @family.save
        format.html { redirect_to @family, notice: "Family was successfully created." }
        format.json { render :show, status: :created, location: @family }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @family.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @family.update(family_params)
        format.html { redirect_to @family, notice: "Family was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @family }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @family.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    account = @family.account
    @family.destroy!

    respond_to do |format|
      format.html { redirect_to account_path(account), notice: "Family was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def run_automation_rules
    due_rules = FamilyBrain::AutomationSchedulerService.new(family: @family).due_rules
    due_rules.each { |rule| AutomationRuleExecutionJob.perform_later(rule.id) }

    redirect_to family_path(@family), notice: "#{due_rules.size} automation rule(s) queued."
  end

  private

  def set_account
    @account = current_user.accounts.find(params.expect(:account_id))
  end

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:id))
  end

  def family_params
    params.expect(family: %i[name timezone locale])
  end

  def available_users_for(account)
    linked_ids = account.families.joins(family_members: :member_users).distinct.pluck("member_users.user_id")
    User.where(id: linked_ids + [current_user.id]).or(User.where(email: current_user.email)).order(:email)
  end
end
