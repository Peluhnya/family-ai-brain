class Account < ApplicationRecord
  AI_ACCESS_MODES = %w[app_default personal_api_key].freeze
  AI_PROVIDERS = %w[openai openai_compatible ollama].freeze

  belongs_to :user
  has_many :families, dependent: :destroy

  encrypts :name, :description, :email, :ai_api_key, :ai_api_base

  validates :name, presence: true
  validates :email, presence: true
  validates :ai_access_mode, inclusion: { in: AI_ACCESS_MODES }
  validates :ai_provider, inclusion: { in: AI_PROVIDERS }
  validates :ai_api_base, presence: true, if: :openai_compatible_personal_ai?

  before_validation :normalize_ai_settings

  def personal_ai?
    ai_access_mode == "personal_api_key"
  end

  def openai_compatible?
    ai_provider == "openai_compatible"
  end

  def ollama?
    ai_provider == "ollama"
  end

  def openai_compatible_personal_ai?
    personal_ai? && openai_compatible?
  end

  def ai_provider_label
    return "OpenAI-compatible" if openai_compatible?
    return "Ollama" if ollama?

    "OpenAI"
  end

  def masked_ai_api_key
    return "not set" if ai_api_key.blank?
    return "[hidden]" if ai_api_key.length < 8

    "#{ai_api_key.first(3)}...#{ai_api_key.last(4)}"
  end

  private

  def normalize_ai_settings
    self.ai_api_base = ai_api_base.presence&.strip
    self.ai_model = ai_model.presence&.strip
  end
end
