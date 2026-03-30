class AutomationRulesController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family, only: :create
  before_action :set_rule, only: :run_now

  def create
    @automation_rule = @family.automation_rules.new(automation_rule_params)

    if @automation_rule.save
      redirect_to family_tab_redirect_path(@family, "automations"), notice: "Automation rule was successfully created."
    else
      prepare_family_page(family: @family, active_tab: "automations", form_overrides: { automation_rule_form: @automation_rule })
      render "families/show", status: :unprocessable_entity
    end
  end

  def run_now
    AutomationRuleExecutionJob.perform_later(@rule.id)
    redirect_to family_tab_redirect_path(@rule.family, "automations"), notice: "Automation rule queued for execution."
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def set_rule
    @rule = AutomationRule.joins(family: :account).where(accounts: { user_id: current_user.id }).find(params.expect(:id))
  end

  def automation_rule_params
    FamilyBrain::AutomationRuleBuilder.new(params: params.expect(automation_rule: [
      :name, :active, :template_key, :time_of_day, :weekday, :day_of_month, :keyword,
      :message_body, :event_type, :summary, :details, :importance, :knowledge_key,
      :knowledge_value, :confidence, :task_title, :task_description, :task_priority,
      :task_status, :task_due_in_days, :task_assigned_to, :calendar_title,
      :calendar_location, :calendar_source, :calendar_start_in_days, :calendar_duration_hours,
      :reminder_title, :reminder_channel, :reminder_trigger_in_days
    ])).attributes
  end
end
