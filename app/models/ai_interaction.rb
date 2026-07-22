class AiInteraction < ApplicationRecord
  include FamilyTabCountsBroadcastable

  belongs_to :family
  belongs_to :user, optional: true
  has_many :ai_effects, foreign_key: :source_ai_interaction_id, dependent: :destroy

  encrypts :content

  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true

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
end
