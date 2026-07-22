class PruneAiInteractionsJob < ApplicationJob
  queue_as :maintenance

  CHAT_RETENTION_DAYS = 90
  METADATA_RETENTION_DAYS = 30
  DEFAULT_BATCH_SIZE = 500

  def perform(now: Time.current)
    deleted = delete_conversations_ending_before(now - chat_retention)
    metadata_compacted = compact_metadata_created_before(now - metadata_retention)

    counts = deleted.merge(metadata_compacted: metadata_compacted)
    Rails.logger.info(
      "ai_interaction_retention_cleanup " \
      "messages_deleted=#{counts[:messages]} conversations_deleted=#{counts[:conversations]} " \
      "effects_deleted=#{counts[:effects]} proposals_deleted=#{counts[:proposals]} " \
      "metadata_compacted=#{counts[:metadata_compacted]}"
    )
    counts
  end

  private

  def chat_retention
    retention_days("AI_CHAT_RETENTION_DAYS", CHAT_RETENTION_DAYS).days
  end

  def metadata_retention
    retention_days("AI_CHAT_METADATA_RETENTION_DAYS", METADATA_RETENTION_DAYS).days
  end

  def batch_size
    ENV.fetch("AI_CHAT_PRUNE_BATCH_SIZE", DEFAULT_BATCH_SIZE).to_i.clamp(50, 5_000)
  end

  def retention_days(environment_key, default)
    ENV.fetch(environment_key, default).to_i.clamp(1, 3_650)
  end

  def compact_metadata_created_before(cutoff)
    AiInteraction
      .where(created_at: ...cutoff)
      .where.not(llm_metadata: [ nil, {} ])
      .in_batches(of: batch_size)
      .sum { |batch| batch.update_all(llm_metadata: {}) }
  end

  def delete_conversations_ending_before(cutoff)
    counts = { messages: 0, conversations: 0, effects: 0, proposals: 0 }
    expired = Conversation.where(last_message_at: ...cutoff).or(
      Conversation.where(last_message_at: nil, started_on: ...cutoff.to_date)
    )

    expired.in_batches(of: batch_size) do |batch|
      conversation_ids = batch.pluck(:id)
      interaction_scope = AiInteraction.where(conversation_id: conversation_ids)
      counts[:effects] += AiEffect.where(source_ai_interaction_id: interaction_scope.select(:id)).delete_all
      counts[:proposals] += AiActionProposal.where(conversation_id: conversation_ids).delete_all
      counts[:messages] += interaction_scope.delete_all
      counts[:conversations] += Conversation.where(id: conversation_ids).delete_all
    end

    counts
  end
end
