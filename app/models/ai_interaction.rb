class AiInteraction < ApplicationRecord
  include FamilyTabCountsBroadcastable

  belongs_to :family
  belongs_to :user, optional: true
  belongs_to :conversation, counter_cache: :messages_count, touch: :last_message_at
  belongs_to :reply_to, class_name: "AiInteraction", optional: true
  has_one :reply, class_name: "AiInteraction", foreign_key: :reply_to_id, dependent: :nullify
  has_many :ai_effects, foreign_key: :source_ai_interaction_id, dependent: :destroy

  encrypts :content

  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true

  before_validation :assign_daily_conversation, on: :create

  scope :assistant_role, -> { where(role: "assistant") }
  scope :tracked_llm_requests, -> { assistant_role.where.not(prompt_version: nil) }

  def estimated_input_tokens
    return input_tokens if input_tokens.present?

    [ system_prompt_tokens, short_term_tokens, user_message_tokens ].compact.sum.presence
  end

  def tracked_llm_request?
    prompt_version.present?
  end

  def section_usage
    llm_metadata.fetch("sections", {})
  end

  private

  def assign_daily_conversation
    return if conversation || family.blank?

    self.conversation = Conversation.for_family_at!(family: family, at: created_at || Time.current)
  end
end
