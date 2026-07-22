class AutomationRulesController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family, only: %i[create update destroy]
  before_action :set_rule, only: %i[run_now toggle_active update destroy]

  def create
    @automation_rule = @family.automation_rules.new(automation_rule_params)

    if @automation_rule.save
      respond_with_family_tab_success(family: @family, active_tab: "automations", notice: "Automation rule was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "automations", form_overrides: { automation_rule_form: @automation_rule }, status: :unprocessable_entity)
    end
  end

  def update
    if @rule.update(automation_rule_params)
      respond_with_family_tab_success(family: @family, active_tab: "automations", notice: "Automation rule was successfully updated.")
    else
      render_family_tab_page(family: @family, active_tab: "automations", form_overrides: { automation_rule_form: @rule }, status: :unprocessable_entity)
    end
  end

  def destroy
    @rule.destroy!
    respond_with_family_tab_success(
      family: @family,
      active_tab: "automations",
      notice: "Automation rule was successfully removed.",
      extra_params: { execution_filter: params[:execution_filter] }
    )
  end

  def run_now
    AutomationRuleExecutionJob.perform_later(@rule.id)
    respond_with_family_tab_success(family: @rule.family, active_tab: "automations", notice: "Automation rule queued for execution.")
  end

  def toggle_active
    @rule.update!(active: !@rule.active?)
    status = @rule.active? ? "enabled" : "disabled"

    respond_with_family_tab_success(
      family: @rule.family,
      active_tab: "automations",
      notice: "Automation rule #{status}.",
      extra_params: { execution_filter: params[:execution_filter] }
    )
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
