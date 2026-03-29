require "active_support/key_generator"

primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

if primary_key.blank? || deterministic_key.blank? || key_derivation_salt.blank?
  secret_seed = Rails.application.secret_key_base

  if secret_seed.present? && !Rails.env.production?
    key_generator = ActiveSupport::KeyGenerator.new(secret_seed, iterations: 1_000)

    primary_key ||= key_generator.generate_key("active-record-encryption-primary", 32)
    deterministic_key ||= key_generator.generate_key("active-record-encryption-deterministic", 32)
    key_derivation_salt ||= key_generator.generate_key("active-record-encryption-salt", 32)
  end
end

if primary_key.present? && deterministic_key.present? && key_derivation_salt.present?
  Rails.application.config.active_record.encryption.primary_key = primary_key
  Rails.application.config.active_record.encryption.deterministic_key = deterministic_key
  Rails.application.config.active_record.encryption.key_derivation_salt = key_derivation_salt
elsif Rails.env.production?
  raise "Active Record encryption keys are not configured for production."
end
