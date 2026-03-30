class ProcessAiInteractionEffectsJob < ApplicationJob
  queue_as :default

  def perform(family_id, user_message_id, assistant_message_id)
    family = Family.find(family_id)
    user_message = family.ai_interactions.find(user_message_id)
    assistant_message = family.ai_interactions.find(assistant_message_id)

    trigger_chat_keyword_automations(family, user_message)

    combined_text = [user_message.content, assistant_message.content].join("\n\n")
    user_text = user_message.content.to_s

    FamilyBrain::KnowledgeSyncService.new(
      family: family,
      text: combined_text,
      source: "chat:auto"
    ).call

    FamilyBrain::TaskSyncService.new(
      family: family,
      text: user_text
    ).call

    FamilyBrain::EventSyncService.new(
      family: family,
      text: user_text
    ).call

    FamilyBrain::ReminderSyncService.new(
      family: family,
      text: user_text
    ).call
  end

  private

  def trigger_chat_keyword_automations(family, user_message)
    family.automation_rules.where(active: true, trigger_type: "chat_keyword").find_each do |rule|
      keyword = rule.trigger_config["keyword"].to_s.strip.downcase
      next if keyword.blank?
      next unless user_message.content.to_s.downcase.include?(keyword)

      AutomationRuleExecutionJob.perform_later(rule.id, { keyword: keyword, message: user_message.content })
    end
  end
end
