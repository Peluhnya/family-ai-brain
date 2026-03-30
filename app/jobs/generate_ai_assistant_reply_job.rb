class GenerateAiAssistantReplyJob < ApplicationJob
  queue_as :default

  include ActionView::RecordIdentifier

  def perform(family_id, user_id, user_message_id, assistant_message_id)
    family = Family.find(family_id)
    user = User.find(user_id)
    user_message = family.ai_interactions.find(user_message_id)
    assistant_message = family.ai_interactions.find(assistant_message_id)

    streamed_content = +""
    result = FamilyBrain::ChatService.new(family: family, user: user, message: user_message).call do |chunk|
      next if chunk.content.blank?

      streamed_content << chunk.content
      assistant_message.content = streamed_content
      broadcast_interaction_update(family, assistant_message)
    end

    assistant_message.update!(
      content: result[:content].presence || streamed_content.presence || "Вибач, я не зміг сформувати відповідь.",
      model: result[:model],
      tokens: result[:tokens]
    )

    broadcast_interaction_update(family, assistant_message)
    ProcessAiInteractionEffectsJob.perform_later(family.id, user_message.id, assistant_message.id)
  rescue StandardError => e
    assistant_message&.update!(
      content: "LLM request failed: #{e.message}",
      model: "local-fallback",
      tokens: nil
    )
    broadcast_interaction_update(family, assistant_message) if family && assistant_message
  end

  private

  def broadcast_interaction_update(family, interaction)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ family, :ai_chat ],
      target: dom_id(interaction),
      partial: "ai_interactions/interaction",
      locals: { interaction: interaction }
    )
  end
end
