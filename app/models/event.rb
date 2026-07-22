class Event < ApplicationRecord
  include FamilyTabCountsBroadcastable
  include FamilyWorkspaceRefreshBroadcastable
  self.family_tab_count_update_fields = %i[start_time]

  SOURCES = %w[manual ai_chat automation_rule google_calendar apple_calendar outlook_calendar imported].freeze

  belongs_to :family

  encrypts :title, :location, :external_id, :source

  validates :title, presence: true
  validates :start_time, presence: true
  validates :source_key, inclusion: { in: SOURCES }, allow_blank: true
  validates :sync_fingerprint, uniqueness: { scope: :family_id }, allow_blank: true
  validate :end_time_after_start_time

  before_validation :normalize_sync_fields

  scope :upcoming_first, -> { order(start_time: :asc, created_at: :desc) }
  scope :recent_first, -> { order(start_time: :desc, created_at: :desc) }

  def self.sync_fingerprint_for(source_key:, external_id:)
    source_value = source_key.to_s.strip
    external_value = external_id.to_s.strip
    return if source_value.blank? || external_value.blank?

    Digest::SHA256.hexdigest("#{source_value}:#{external_value}")
  end

  private

  def normalize_sync_fields
    normalized_source = normalize_source_value(source_key.presence || source)
    self.source_key = normalized_source
    self.source = normalized_source if source.blank? || normalized_source.present?
    self.sync_fingerprint = self.class.sync_fingerprint_for(source_key: normalized_source, external_id:)
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
