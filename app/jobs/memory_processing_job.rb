class MemoryProcessingJob < ApplicationJob
  queue_as :default

  def perform(family_id, user_message_id, assistant_message_id = nil)
    family = Family.find(family_id)
    user_message = family.ai_interactions.find(user_message_id)
    assistant_message = family.ai_interactions.find_by(id: assistant_message_id)

    result = FamilyBrain::MemoryProcessor.new(
      family: family,
      user_message: user_message,
      assistant_message: assistant_message
    ).call
    Rails.logger.info(
      "family_brain_memory_processed family_id=#{family.id} interaction_id=#{user_message.id} " \
      "life_logs=#{result[:life_logs].size} knowledge=#{result[:knowledge].size} assistant_interaction_id=#{assistant_message_id || 0}"
    )
  end
end
