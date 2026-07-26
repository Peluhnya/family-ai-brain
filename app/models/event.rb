class Event < ApplicationRecord
  include FamilyTabCountsBroadcastable
  include FamilyWorkspaceRefreshBroadcastable
  self.family_tab_count_update_fields = %i[start_time end_time]

  SOURCES = %w[manual ai_chat automation_rule google_calendar apple_calendar outlook_calendar imported].freeze

  belongs_to :family
  belongs_to :calendar_connection, optional: true

  encrypts :title, :location, :external_id, :external_calendar_id, :external_event_id, :source

  validates :title, presence: true
  validates :start_time, presence: true
  validates :source_key, inclusion: { in: SOURCES }, allow_blank: true
  validates :sync_fingerprint, uniqueness: { scope: :family_id }, allow_blank: true
  validate :end_time_after_start_time

  before_validation :normalize_sync_fields

  scope :upcoming_first, -> { order(start_time: :asc, created_at: :desc) }
  scope :upcoming_or_ongoing, -> { where("COALESCE(end_time, start_time) >= ?", Time.current.beginning_of_day).upcoming_first }
  scope :recent_first, -> { order(start_time: :desc, created_at: :desc) }

  def display_end_time
    return end_time unless all_day? && end_time.present?

    end_time - 1.day
  end

  def self.sync_fingerprint_for(source_key:, external_id:, calendar_connection_id: nil)
    source_value = source_key.to_s.strip
    external_value = external_id.to_s.strip
    return if source_value.blank? || external_value.blank?

    identity = [ source_value, calendar_connection_id, external_value ].compact.join(":")
    Digest::SHA256.hexdigest(identity)
  end

  private

  def normalize_sync_fields
    normalized_source = normalize_source_value(source_key.presence || source)
    self.source_key = normalized_source
    self.source = normalized_source if source.blank? || normalized_source.present?
    self.sync_fingerprint = self.class.sync_fingerprint_for(
      source_key: normalized_source,
      external_id:,
      calendar_connection_id:
    )
  end

  def normalize_source_value(value)
    normalized = value.to_s.strip.downcase
    return "manual" if normalized.blank?
    return normalized if SOURCES.include?(normalized)

    "imported"
  end

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?
    return if end_time >= start_time

    errors.add(:end_time, "must be after start time")
  end
end
