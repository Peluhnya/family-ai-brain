class Conversation < ApplicationRecord
  STATUSES = %w[active archived].freeze

  belongs_to :family
  has_many :ai_interactions, dependent: :destroy
  has_many :ai_action_proposals, dependent: :destroy

  validates :title, :started_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :started_on, uniqueness: { scope: :family_id }

  scope :recent_first, -> { order(started_on: :desc, id: :desc) }
  scope :active, -> { where(status: "active") }
  scope :created_before, ->(date) { where(started_on: ...date) }

  def self.find_or_build_for_family_at(family:, at: Time.current)
    started_on = family.local_date(at)
    family.conversations.find_by(started_on: started_on) || family.conversations.build(
      title: started_on.strftime("%d.%m.%Y"),
      started_on: started_on,
      status: "active"
    )
  end

  def self.for_family_at!(family:, at: Time.current)
    started_on = family.local_date(at)
    conversation = family.conversations.find_or_create_by!(started_on: started_on) do |record|
      record.title = started_on.strftime("%d.%m.%Y")
      record.status = "active"
      record.last_message_at = at
    end

    family.conversations.active.where.not(id: conversation.id).update_all(
      status: "archived",
      updated_at: Time.current
    )
    conversation.update!(status: "active") unless conversation.status == "active"
    conversation
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
