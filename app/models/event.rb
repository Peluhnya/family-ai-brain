class Event < ApplicationRecord
  belongs_to :family

  encrypts :title, :location, :external_id, :source

  validates :title, presence: true
  validates :start_time, presence: true
  validate :end_time_after_start_time

  scope :upcoming_first, -> { order(start_time: :asc, created_at: :desc) }
  scope :recent_first, -> { order(start_time: :desc, created_at: :desc) }

  private

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?
    return if end_time >= start_time

    errors.add(:end_time, "must be after start time")
  end
end
