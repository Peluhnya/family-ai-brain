class AutomationRuleExecution < ApplicationRecord
  include FamilyWorkspaceRefreshBroadcastable

  STATUSES = %w[completed].freeze

  belongs_to :automation_rule
  belongs_to :family

  validates :action_type, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
