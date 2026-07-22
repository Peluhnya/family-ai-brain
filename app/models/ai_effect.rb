class AiEffect < ApplicationRecord
  STATUSES = %w[pending completed skipped failed].freeze

  belongs_to :family
  belongs_to :source_ai_interaction, class_name: "AiInteraction"

  encrypts :details, :error_message

  validates :action_type, :action_fingerprint, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :action_fingerprint, uniqueness: { scope: :source_ai_interaction_id }

  scope :recent_first, -> { order(created_at: :desc) }

  def entity
    return if entity_type.blank? || entity_id.blank?

    entity_type.safe_constantize&.find_by(id: entity_id)
  end
end
