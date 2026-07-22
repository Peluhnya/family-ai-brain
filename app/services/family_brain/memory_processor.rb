module FamilyBrain
  class MemoryProcessor
    def initialize(family:, user_message:, assistant_message: nil, now: Time.current)
      @family = family
      @user_message = user_message
      @assistant_message = assistant_message
      @now = now
    end

    def call
      trigger_chat_keyword_automations

      # Knowledge and episodic memory are planned by the same turn planner as
      # operational actions. Re-running independent extractors here can classify
      # the same sentence differently or lose mixed action-and-memory turns.
      { life_logs: [], knowledge: [] }
    end

    private

    def trigger_chat_keyword_automations
      @family.automation_rules.where(active: true).find_each do |rule|
        next unless rule.trigger_type == "chat_keyword"

        keyword = rule.trigger_config["keyword"].to_s.strip.downcase
        next if keyword.blank?
        next unless keyword_matches?(rule, keyword)

        AutomationRuleExecutionJob.perform_later(rule.id, {
          keyword: keyword,
          message: @user_message.content,
          source_type: "AiInteraction",
          source_id: @user_message.id
        })
      end
    end

    def keyword_matches?(rule, keyword)
      message = @user_message.content.to_s.downcase.strip

      case rule.trigger_config["match_mode"].presence || "contains"
      when "exact_command"
        FamilyBrain::GroundedExtraction.normalize_text(message) == FamilyBrain::GroundedExtraction.normalize_text(keyword)
      when "word"
        message.match?(/(?<![\p{L}\p{N}])#{Regexp.escape(keyword)}(?![\p{L}\p{N}])/iu)
      else
        message.include?(keyword)
      end
    end
  end
end
