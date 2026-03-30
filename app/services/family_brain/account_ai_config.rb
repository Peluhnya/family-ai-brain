module FamilyBrain
  class AccountAiConfig
    def initialize(account:)
      @account = account
    end

    def api_key
      return @account.ai_api_key if @account.personal_ai? && @account.ai_api_key.present?

      ENV["OPENAI_API_KEY"]
    end

    def api_base
      return @account.ai_api_base if @account.personal_ai? && @account.ai_api_base.present?

      ENV["OPENAI_API_BASE"]
    end

    def provider
      @account.ai_provider.presence || "openai"
    end

    def chat_model
      @account.ai_model.presence || ENV.fetch("AI_CHAT_MODEL", "gpt-4o-mini")
    end

    def embedding_model
      ENV.fetch("AI_EMBEDDING_MODEL", "text-embedding-3-small")
    end

    def personal_configured?
      @account.personal_ai? && @account.ai_api_key.present?
    end

    def available?
      api_key.present?
    end

    def label
      return "OpenAI-compatible" if provider == "openai_compatible"

      "OpenAI"
    end
  end
end
