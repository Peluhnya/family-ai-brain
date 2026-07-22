class ProcessAiInteractionEffectsJob < ApplicationJob
  queue_as :default

  def perform(family_id, user_message_id, assistant_message_id)
    family = Family.find(family_id)
    user_message = family.ai_interactions.find(user_message_id)
    family.ai_interactions.find(assistant_message_id)

    FamilyBrain::MemoryProcessor.new(family: family, user_message: user_message).call
  end
end
