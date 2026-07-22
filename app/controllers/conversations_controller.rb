class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family
  before_action :set_conversation

  def messages
    page = FamilyBrain::ConversationMessagePage.new(
      conversation: @conversation,
      before_id: params[:before_id]
    )
    @ai_interactions = page.messages
    @has_older_messages = page.has_older?
    @older_messages_before_id = page.before_id

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to family_path(@family, conversation_id: @conversation.id) }
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def set_conversation
    @conversation = @family.conversations.find(params.expect(:id))
  end
end
