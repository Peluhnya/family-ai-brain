class FamiliesController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_account, only: %i[index new create]
  before_action :set_family, only: %i[show edit update destroy run_automation_rules]

  def index
    @families = @account.families.includes(family_members: :member_users).order(:name)
  end

  def show
    prepare_family_page(family: @family, active_tab: params[:tab])

    if turbo_frame_request?
      render partial: "families/tab_content", locals: { family: @family, active_tab: @active_family_tab }
    end
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

    respond_with_family_tab_success(
      family: @family,
      active_tab: "automations",
      notice: "#{due_rules.size} automation rule(s) queued."
    )
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
end
