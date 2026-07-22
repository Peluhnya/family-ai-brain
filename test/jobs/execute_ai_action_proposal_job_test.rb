require "test_helper"

class ExecuteAiActionProposalJobTest < ActiveJob::TestCase
  setup do
    @family = families(:one)
    @conversation = Conversation.for_family_at!(family: @family)
    @message = @family.ai_interactions.create!(
      conversation: @conversation,
      role: "user",
      content: "Додай задачу купити молоко",
      user: users(:one),
      model: "human"
    )
  end

  test "executes a ready proposal once" do
    proposal = ready_task_proposal

    assert_difference -> { @family.tasks.count }, 1 do
      ExecuteAiActionProposalJob.perform_now(proposal.id)
      ExecuteAiActionProposalJob.perform_now(proposal.id)
    end

    assert_equal "completed", proposal.reload.state
    assert_equal "Task", proposal.entity_type
    assert_equal "Купити молоко", proposal.entity.title
  end

  test "does not execute an unconfirmed proposal" do
    proposal = ready_task_proposal
    proposal.update!(state: "awaiting_confirmation")

    assert_no_difference -> { @family.tasks.count } do
      ExecuteAiActionProposalJob.perform_now(proposal.id)
    end

    assert_equal "awaiting_confirmation", proposal.reload.state
  end

  private

  def ready_task_proposal
    proposal = @family.ai_action_proposals.new(
      conversation: @conversation,
      source_ai_interaction: @message,
      action_kind: "create_task",
      action_fingerprint: SecureRandom.hex,
      state: "ready",
      intent_strength: "explicit",
      risk: "low"
    )
    proposal.payload_data = {
      kind: "create_task",
      record_id: 0,
      title: "Купити молоко",
      description: "",
      assignee_name: "",
      priority: 3,
      due_at: "",
      trigger_at: "",
      channel: "app",
      start_at: "",
      end_at: "",
      all_day: false,
      location: "",
      evidence: [ @message.content ],
      changed_fields: []
    }
    proposal.evidence_data = [ { source_type: "AiInteraction", source_id: @message.id, quote: @message.content } ]
    proposal.save!
    proposal
  end
end
