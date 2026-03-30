class FamilyKnowledge < ApplicationRecord
  self.table_name = "family_knowledge"

  belongs_to :family

  encrypts :key, deterministic: true
  encrypts :value, :source
  has_neighbors :embedding

  validates :key, presence: true
  validates :value, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }

  scope :priority_first, -> { order(confidence: :desc, updated_at: :desc, created_at: :desc) }
end
