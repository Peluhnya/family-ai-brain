class AiInteraction < ApplicationRecord
  include FamilyTabCountsBroadcastable

  belongs_to :family
  belongs_to :user, optional: true

  encrypts :content

  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
end
