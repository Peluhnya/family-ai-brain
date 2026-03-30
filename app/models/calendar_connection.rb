class CalendarConnection < ApplicationRecord
  include FamilyTabCountsBroadcastable
  self.family_tab_count_update_fields = %i[active]

  PROVIDERS = %w[google_calendar apple_calendar outlook_calendar].freeze

  belongs_to :family

  encrypts :display_name, :remote_calendar_id, :access_token, :refresh_token, :sync_cursor, :last_error

  validates :provider, presence: true, inclusion: { in: PROVIDERS }

  before_validation :normalize_sync_fields

  scope :active_first, -> { order(active: :desc, updated_at: :desc) }

  def source_key
    provider
  end

  def google_calendar?
    provider == "google_calendar"
  end

  def effective_remote_calendar_id
    return remote_calendar_id if remote_calendar_id.present?
    return nil if google_calendar?

    nil
  end

  def ready_for_remote_sync?
    effective_remote_calendar_id.present? && (access_token.present? || refresh_token.present? || settings["public_url"].present?)
  end

  private

  def normalize_sync_fields
    self.remote_calendar_id = remote_calendar_id.to_s.strip.presence
    self.display_name = display_name.to_s.strip.presence
    self.remote_calendar_key = digest(remote_calendar_id)
    self.connection_fingerprint = digest([provider, remote_calendar_id].join(":"))
  end

  def digest(value)
    value = value.to_s.strip
    return if value.blank?

    Digest::SHA256.hexdigest(value)
  end
end
