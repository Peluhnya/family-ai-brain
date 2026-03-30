class LifeLog < ApplicationRecord
  belongs_to :family

  encrypts :event_type, :summary, :raw_text
  has_neighbors :embedding

  validates :event_type, presence: true
  validates :summary, presence: true
  validates :importance, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }

  scope :recent_first, -> { order(happened_at: :desc, created_at: :desc) }
  scope :priority_first, -> { order(importance: :desc, happened_at: :desc, created_at: :desc) }
end
