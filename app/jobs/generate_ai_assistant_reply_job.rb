class GenerateAiAssistantReplyJob < ApplicationJob
  queue_as :default

  include ActionView::RecordIdentifier

  def perform(family_id, user_id, user_message_id, assistant_message_id)
    family = Family.find(family_id)
    user = User.find(user_id)
    user_message = family.ai_interactions.find(user_message_id)
    assistant_message = family.ai_interactions.find(assistant_message_id)

    streamed_content = +""
    result = FamilyBrain::Orchestrator.new(family: family, user: user, user_message: user_message).call(
      on_status: ->(status) { broadcast_status(family, assistant_message, status) }
    ) do |chunk|
      next if chunk.content.blank?

      streamed_content << chunk.content
      assistant_message.content = streamed_content
      broadcast_interaction_update(family, assistant_message)
    end

    usage_metadata = (result[:usage_metadata] || {}).deep_merge(orchestrator: result[:orchestrator] || {})

    assistant_message.update!(
      content: result[:content].presence || streamed_content.presence || "Вибач, я не зміг сформувати відповідь.",
      model: result[:model],
      tokens: result[:tokens],
      input_tokens: result[:input_tokens],
      output_tokens: result[:output_tokens],
      system_prompt_tokens: result.dig(:usage_metadata, :estimates, :system_prompt_tokens),
      system_prompt_chars: result.dig(:usage_metadata, :estimates, :system_prompt_chars),
      short_term_tokens: result.dig(:usage_metadata, :estimates, :short_term_tokens),
      short_term_message_count: result.dig(:usage_metadata, :estimates, :short_term_message_count),
      user_message_tokens: result.dig(:usage_metadata, :estimates, :user_message_tokens),
      prompt_version: result[:prompt_version],
      llm_metadata: usage_metadata
    )

    Rails.logger.info(
      "ai_usage account_id=#{family.account_id} family_id=#{family.id} interaction_id=#{assistant_message.id} " \
      "model=#{result[:model]} input_tokens=#{result[:input_tokens] || 0} output_tokens=#{result[:output_tokens] || 0} " \
      "system_prompt_tokens=#{result.dig(:usage_metadata, :estimates, :system_prompt_tokens) || 0} " \
      "short_term_tokens=#{result.dig(:usage_metadata, :estimates, :short_term_tokens) || 0} " \
      "user_message_tokens=#{result.dig(:usage_metadata, :estimates, :user_message_tokens) || 0} " \
      "prompt_version=#{result[:prompt_version] || 'none'}"
    )

    broadcast_interaction_update(family, assistant_message)
    MemoryProcessingJob.perform_later(family.id, user_message.id, assistant_message.id)
  rescue StandardError => e
    assistant_message&.update!(
      content: "LLM request failed: #{e.message}",
      model: "local-fallback",
      tokens: nil
    )
    broadcast_interaction_update(family, assistant_message) if family && assistant_message
  end

  private

  def broadcast_status(family, assistant_message, status)
    assistant_message.content = status
    broadcast_interaction_update(family, assistant_message)
  end

  def broadcast_interaction_update(family, interaction)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ family, :ai_chat ],
      target: dom_id(interaction),
      partial: "ai_interactions/interaction",
      locals: { interaction: interaction }
    )
  end
end
