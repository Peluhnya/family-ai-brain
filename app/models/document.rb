class Document < ApplicationRecord
  include FamilyTabCountsBroadcastable
  include FamilyWorkspaceRefreshBroadcastable

  belongs_to :family

  encrypts :title, :content
  has_neighbors :embedding

  validates :title, presence: true
  validates :content, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
