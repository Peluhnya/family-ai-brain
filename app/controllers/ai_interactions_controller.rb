class AiInteractionsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family

  def create
    @user_message = @family.ai_interactions.create!(
      user: current_user,
      role: "user",
      content: ai_interaction_params[:content],
      model: "human"
    )

    @assistant_message = @family.ai_interactions.create!(
      role: "assistant",
      content: "Думаю...",
      model: FamilyBrain::AccountAiConfig.new(account: @family.account).chat_model,
      tokens: nil
    )

    GenerateAiAssistantReplyJob.perform_later(@family.id, current_user.id, @user_message.id, @assistant_message.id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to family_tab_redirect_path(@family, "chat") }
    end
  rescue ActiveRecord::RecordInvalid
    prepare_family_page(family: @family, active_tab: "chat", form_overrides: { ai_interaction: @family.ai_interactions.new })

    respond_to do |format|
      format.turbo_stream { redirect_to family_tab_redirect_path(@family, "chat"), alert: "Message could not be sent." }
      format.html { render "families/show", status: :unprocessable_entity }
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def ai_interaction_params
    params.expect(ai_interaction: [:content])
  end
end
