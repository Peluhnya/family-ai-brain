module FamilyBrain
  class MemoryTurnPolicy
    def initialize(assistant_message:)
      @assistant_message = assistant_message
    end

    def extractable?
      return true unless @assistant_message

      metadata = @assistant_message.llm_metadata.to_h.deep_stringify_keys
      orchestrator = metadata.fetch("orchestrator", {})
      return false if orchestrator.blank?
      return false if orchestrator["actions_planned"].to_i.positive?
      return false if Array(orchestrator["tool_results"]).any?
      return false if orchestrator["clarification_required"] == true
      return false if orchestrator["planning_error"].present?

      true
    end
  end
end
