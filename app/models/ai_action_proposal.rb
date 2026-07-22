class AiActionProposal < ApplicationRecord
  AWAITING_INPUT_STATES = %w[awaiting_clarification awaiting_confirmation].freeze
  ACTIVE_STATES = (AWAITING_INPUT_STATES + %w[ready executing]).freeze
  TERMINAL_STATES = %w[completed rejected expired failed].freeze
  STATES = (ACTIVE_STATES + TERMINAL_STATES).freeze
  INTENT_STRENGTHS = %w[explicit inferred].freeze
  RISKS = %w[low medium high].freeze

  belongs_to :family
  belongs_to :conversation
  belongs_to :source_ai_interaction, class_name: "AiInteraction"
  belongs_to :confirmation_ai_interaction, class_name: "AiInteraction", optional: true
  belongs_to :confirmed_by, class_name: "User", optional: true

  encrypts :payload, :evidence, :error_message

  validates :action_kind, :action_fingerprint, presence: true
  validates :state, inclusion: { in: STATES }
  validates :intent_strength, inclusion: { in: INTENT_STRENGTHS }
  validates :risk, inclusion: { in: RISKS }
  validates :action_fingerprint, uniqueness: { scope: :source_ai_interaction_id }
  validate :consistent_family_and_conversation

  scope :active, -> { where(state: ACTIVE_STATES) }
  scope :awaiting_input, -> { where(state: AWAITING_INPUT_STATES) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def payload_data
    parse_encrypted_json(payload, {})
  end

  def payload_data=(value)
    self.payload = value.to_h.deep_stringify_keys.to_json
  end

  def evidence_data
    parse_encrypted_json(evidence, [])
  end

  def evidence_data=(value)
    self.evidence = Array(value).to_json
  end

  def active?
    state.in?(ACTIVE_STATES)
  end

  def terminal?
    state.in?(TERMINAL_STATES)
  end

  def awaiting_input?
    state.in?(AWAITING_INPUT_STATES)
  end

  def expired?(at = Time.current)
    expires_at.present? && expires_at <= at
  end

  def entity
    return if entity_type.blank? || entity_id.blank?

    entity_type.safe_constantize&.find_by(id: entity_id)
  end

  private

  def parse_encrypted_json(value, fallback)
    return fallback if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError, TypeError
    fallback
  end

  def consistent_family_and_conversation
    if source_ai_interaction && (source_ai_interaction.family_id != family_id || source_ai_interaction.conversation_id != conversation_id)
      errors.add(:source_ai_interaction, "must belong to the proposal family and conversation")
    end
    if confirmation_ai_interaction &&
        (confirmation_ai_interaction.family_id != family_id || confirmation_ai_interaction.conversation_id != conversation_id)
      errors.add(:confirmation_ai_interaction, "must belong to the proposal family and conversation")
    end
  end
end
