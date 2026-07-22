require "test_helper"

class AiActionProposalTest < ActiveSupport::TestCase
  test "round trips encrypted payload and evidence" do
    family = families(:one)
    conversation = Conversation.for_family_at!(family: family)
    message = family.ai_interactions.create!(conversation: conversation, role: "user", content: "Купити молоко")
    proposal = family.ai_action_proposals.new(
      conversation: conversation,
      source_ai_interaction: message,
      action_kind: "create_task",
      action_fingerprint: "fingerprint",
      state: "ready",
      intent_strength: "explicit",
      risk: "low"
    )
    proposal.payload_data = { kind: "create_task", title: "Купити молоко" }
    proposal.evidence_data = [ { source_type: "AiInteraction", source_id: message.id, quote: message.content } ]
    proposal.save!

    assert_equal "Купити молоко", proposal.reload.payload_data["title"]
    assert_equal message.content, proposal.evidence_data.first["quote"]
  end
end
