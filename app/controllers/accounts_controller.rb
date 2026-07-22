class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account, only: %i[show edit update destroy test_ai_connection]

  def index
    @accounts = current_user.accounts.includes(families: { family_members: :member_users }).order(updated_at: :desc)
  end

  def show
    @families = @account.families.includes(family_members: :member_users).order(:name)
    @family = @account.families.new(timezone: "Europe/Berlin", locale: I18n.locale.to_s)
    load_ai_usage if ai_debug_ui_enabled?
  end

  def new
    @account = current_user.accounts.new(active: true, email: current_user.email, ai_access_mode: "app_default")
  end

  def edit; end

  def create
    @account = current_user.accounts.new(account_params)

    respond_to do |format|
      if @account.save
        format.html { redirect_to @account, notice: "Account was successfully created." }
        format.json { render :show, status: :created, location: @account }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @account.update(account_params)
        format.html { redirect_to @account, notice: "Account was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @account }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @account.destroy!

    respond_to do |format|
      format.html { redirect_to accounts_path, notice: "Account was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def test_ai_connection
    result = FamilyBrain::ConnectionTestService.new(account: @account).call

    if result[:ok]
      redirect_to account_path(@account), notice: result[:message]
    else
      redirect_to account_path(@account), alert: result[:message]
    end
  end

  private

  def ai_debug_ui_enabled?
    Rails.env.development? || Rails.env.test?
  end

  def set_account
    @account = current_user.accounts.find(params.expect(:id))
  end

  def account_params
    permitted = params.expect(account: %i[name description email active ai_access_mode ai_provider ai_api_key ai_api_base ai_model])

    if action_name == "update" && permitted[:ai_api_key].blank?
      permitted.delete(:ai_api_key)
    end

    permitted
  end

  def load_ai_usage
    usage_scope = @account.ai_interactions.tracked_llm_requests
    @recent_ai_requests = usage_scope.includes(:family).order(created_at: :desc).limit(12)
    @ai_usage_summary = {
      requests_count: usage_scope.count,
      total_tokens: usage_scope.sum(:tokens),
      total_input_tokens: usage_scope.sum(:input_tokens),
      total_output_tokens: usage_scope.sum(:output_tokens),
      total_system_prompt_tokens: usage_scope.sum(:system_prompt_tokens),
      average_input_tokens: usage_scope.average(:input_tokens)&.round,
      average_output_tokens: usage_scope.average(:output_tokens)&.round,
      average_system_prompt_tokens: usage_scope.average(:system_prompt_tokens)&.round,
      average_short_term_tokens: usage_scope.average(:short_term_tokens)&.round,
      average_user_message_tokens: usage_scope.average(:user_message_tokens)&.round,
      fallback_count: @account.ai_interactions.assistant_role.where(model: "local-fallback").count
    }

    @ai_usage_by_family = usage_scope.group(:family_id).sum(:tokens).sort_by { |_, tokens| -tokens.to_i }.filter_map do |family_id, tokens|
      family = @families.find { |item| item.id == family_id }
      next unless family

      family_scope = usage_scope.where(family_id: family_id)
      {
        family: family,
        requests_count: family_scope.count,
        total_tokens: tokens.to_i,
        average_input_tokens: family_scope.average(:input_tokens)&.round,
        average_system_prompt_tokens: family_scope.average(:system_prompt_tokens)&.round
      }
    end
  end
end
