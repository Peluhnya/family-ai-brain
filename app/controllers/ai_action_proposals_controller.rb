class AiActionProposalsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_family
  before_action :set_proposal

  def confirm
    @proposal.with_lock do
      expire_if_needed!
      if @proposal.state == "awaiting_confirmation"
        @proposal.update!(
          state: "ready",
          confirmed_by: current_user,
          expires_at: nil
        )
        ExecuteAiActionProposalJob.perform_later(@proposal.id)
      end
    end

    respond_with_proposal
  end

  def reject
    @proposal.with_lock do
      expire_if_needed!
      if @proposal.awaiting_input?
        @proposal.update!(
          state: "rejected",
          confirmed_by: current_user,
          expires_at: nil
        )
      end
    end

    respond_with_proposal
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def set_proposal
    @proposal = @family.ai_action_proposals.find(params.expect(:id))
  end

  def expire_if_needed!
    @proposal.update!(state: "expired") if @proposal.active? && @proposal.expired?
  end

  def respond_with_proposal
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@proposal),
          partial: "ai_action_proposals/proposal",
          locals: { proposal: @proposal }
        )
      end
      format.html { redirect_to tab_family_path(@family, tab: "chat") }
    end
  end
end
