class Reminder < ApplicationRecord
  include FamilyTabCountsBroadcastable
  self.family_tab_count_update_fields = %i[status trigger_at]

  CHANNELS = %w[app email sms].freeze
  STATUSES = %w[pending sent canceled].freeze

  belongs_to :family

  encrypts :title

  validates :title, presence: true
  validates :trigger_at, presence: true
  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :upcoming_first, -> { order(Arel.sql("CASE WHEN status = 'pending' THEN 0 ELSE 1 END"), trigger_at: :asc, created_at: :desc) }
  scope :active, -> { where(status: "pending") }

  def pending?
    status == "pending"
  end
end
