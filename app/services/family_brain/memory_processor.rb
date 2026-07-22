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

      return { life_logs: [], knowledge: [] } unless FamilyBrain::MemoryTurnPolicy.new(
        assistant_message: @assistant_message
      ).extractable?

      {
        life_logs: FamilyBrain::LifeLogSyncService.new(
          family: @family,
          text: @user_message.content,
          now: @now
        ).call,
        knowledge: FamilyBrain::KnowledgeSyncService.new(
          family: @family,
          text: @user_message.content,
          source: "chat:auto",
          now: @now
        ).call
      }
    end

    private

    def trigger_chat_keyword_automations
      @family.automation_rules.where(active: true, trigger_type: "chat_keyword").find_each do |rule|
        keyword = rule.trigger_config["keyword"].to_s.strip.downcase
        next if keyword.blank?
        next unless @user_message.content.to_s.downcase.include?(keyword)

        AutomationRuleExecutionJob.perform_later(rule.id, {
          keyword: keyword,
          message: @user_message.content,
          source_type: "AiInteraction",
          source_id: @user_message.id
        })
      end
    end
  end
end
