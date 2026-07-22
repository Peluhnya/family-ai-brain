require "test_helper"

class PruneAiInteractionsJobTest < ActiveJob::TestCase
  setup do
    @family = families(:one)
    @now = Time.zone.local(2026, 7, 22, 12)
  end

  test "compacts old metadata and deletes expired daily conversations in batches" do
    expired_conversation = conversation_at(@now - 100.days)
    expired_message = message_in(expired_conversation, created_at: @now - 100.days, metadata: { "debug" => true })
    effect = @family.ai_effects.create!(
      source_ai_interaction: expired_message,
      action_type: "create_task",
      action_fingerprint: "expired-message-effect",
      status: "completed"
    )
    proposal = @family.ai_action_proposals.new(
      conversation: expired_conversation,
      source_ai_interaction: expired_message,
      action_kind: "create_task",
      action_fingerprint: "expired-message-proposal",
      state: "completed",
      intent_strength: "explicit",
      risk: "low"
    )
    proposal.payload_data = { kind: "create_task", title: "Expired" }
    proposal.save!
    compacted_conversation = conversation_at(@now - 45.days)
    compacted_message = message_in(compacted_conversation, created_at: @now - 45.days, metadata: { "debug" => true })
    recent_conversation = conversation_at(@now - 5.days)
    recent_message = message_in(recent_conversation, created_at: @now - 5.days, metadata: { "debug" => true })
    empty_expired_conversation = @family.conversations.create!(
      title: (@now.to_date - 101.days).strftime("%d.%m.%Y"),
      started_on: @now.to_date - 101.days,
      status: "archived"
    )

    counts = PruneAiInteractionsJob.perform_now(now: @now)

    assert_equal 1, counts[:messages]
    assert_equal 2, counts[:conversations]
    assert_equal 1, counts[:effects]
    assert_equal 1, counts[:proposals]
    assert_equal 1, counts[:metadata_compacted]
    assert_not AiInteraction.exists?(expired_message.id)
    assert_not AiEffect.exists?(effect.id)
    assert_not AiActionProposal.exists?(proposal.id)
    assert_not Conversation.exists?(empty_expired_conversation.id)
    assert_empty compacted_message.reload.llm_metadata
    assert_equal({ "debug" => true }, recent_message.reload.llm_metadata)
  end

  private

  def conversation_at(time)
    conversation = @family.conversations.create!(
      title: time.to_date.strftime("%d.%m.%Y"),
      started_on: time.to_date,
      status: "archived",
      last_message_at: time
    )
    conversation
  end

  def message_in(conversation, created_at:, metadata:)
    message = @family.ai_interactions.create!(
      conversation: conversation,
      role: "assistant",
      content: "Retention test",
      llm_metadata: metadata,
      created_at: created_at,
      updated_at: created_at
    )
    conversation.update_columns(last_message_at: created_at, updated_at: created_at)
    message
  end
end
