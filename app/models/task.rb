class Task < ApplicationRecord
  include FamilyTabCountsBroadcastable
  include FamilyWorkspaceRefreshBroadcastable
  self.family_tab_count_update_fields = %i[status]

  STATUSES = %w[pending in_progress done canceled].freeze

  belongs_to :family
  belongs_to :assignee, class_name: "FamilyMember", foreign_key: :assigned_to, optional: true

  encrypts :title, :description

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }

  scope :open_first, -> { order(Arel.sql("CASE WHEN status IN ('pending', 'in_progress') THEN 0 ELSE 1 END"), priority: :desc, due_at: :asc, created_at: :desc) }
  scope :active, -> { where(status: %w[pending in_progress]) }
end
