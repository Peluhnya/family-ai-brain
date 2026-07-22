class ExecuteAiActionProposalJob < ApplicationJob
  queue_as :default

  include ActionView::RecordIdentifier

  def perform(proposal_id)
    proposal = AiActionProposal.find(proposal_id)
    action = nil

    proposal.with_lock do
      return if proposal.terminal?
      if proposal.expired?
        proposal.update!(state: "expired")
        broadcast(proposal)
        return
      end
      return unless proposal.state == "ready"

      proposal.update!(state: "executing")
      action = proposal.payload_data
    end
    broadcast(proposal)

    result = FamilyBrain::ToolExecutor.new(
      family: proposal.family,
      user_message: proposal.source_ai_interaction,
      source_user_text: verified_source_text(proposal),
      locale: FamilyBrain::LanguageResolver.for_message(
        family: proposal.family,
        message: proposal.source_ai_interaction
      )
    ).call([ action ]).first

    proposal.with_lock do
      proposal.update!(
        state: result.status == "failed" ? "failed" : "completed",
        entity_type: result.entity_type,
        entity_id: result.entity_id,
        executed_at: Time.current,
        error_message: result.status == "failed" ? result.message : nil
      )
    end
    broadcast(proposal)
  rescue StandardError => error
    proposal&.update(state: "failed", error_message: "#{error.class}: #{error.message}")
    broadcast(proposal) if proposal
    raise
  end

  private

  def verified_source_text(proposal)
    proposal.evidence_data.filter_map do |item|
      data = item.to_h.deep_stringify_keys
      next unless data["source_type"] == "AiInteraction"

      allowed_roles = proposal.action_kind.in?(%w[create_document update_document]) ? %w[user assistant] : [ "user" ]
      message = proposal.family.ai_interactions.find_by(id: data["source_id"], role: allowed_roles)
      next unless message
      next unless FamilyBrain::GroundedExtraction.evidence_fragment_present?(message.content, data["quote"])

      message.content
    end.uniq.join("\n")
  end

  def broadcast(proposal)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ proposal.family, :ai_chat ],
      target: dom_id(proposal),
      partial: "ai_action_proposals/proposal",
      locals: { proposal: proposal }
    )
  end
end
