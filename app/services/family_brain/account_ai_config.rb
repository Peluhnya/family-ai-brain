module FamilyBrain
  class AccountAiConfig
    OLLAMA_DEFAULT_API_BASE = "http://localhost:11434/v1".freeze
    OPENAI_DEFAULT_CHAT_MODEL = "gpt-4o-mini".freeze
    OPENAI_DEFAULT_EMBEDDING_MODEL = "text-embedding-3-small".freeze
    OLLAMA_DEFAULT_CHAT_MODEL = "gemma3:1b".freeze
    OLLAMA_DEFAULT_EMBEDDING_MODEL = "nomic-embed-text".freeze
    OLLAMA_DEFAULT_NUM_CTX = 4096

    def initialize(account:)
      @account = account
    end

    def api_key
      return @account.ai_api_key if personal_account_ai? && @account.ai_api_key.present?

      env_api_key
    end

    def api_base
      return @account.ai_api_base if personal_account_ai? && @account.ai_api_base.present?

      env_api_base
    end

    def provider
      return "openai" if @account.chatgpt_account?

      @account.ai_provider.presence || "openai"
    end

    def chat_model
      @account.ai_model.presence || env_chat_model
    end

    def embedding_model
      env_embedding_model
    end

    def personal_configured?
      return personal_account_ai? && @account.ai_api_base.present? if ollama?
      return personal_account_ai? && @account.ai_api_key.present? && @account.ai_api_base.present? if openai_compatible?

      personal_account_ai? && @account.ai_api_key.present?
    end

    def available?
      return api_base.present? if ollama?
      return api_key.present? && api_base.present? if openai_compatible?

      api_key.present?
    end

    def label
      @account.ai_provider_label
    end

    def ruby_llm_provider
      return :ollama if ollama?

      :openai
    end

    def chatgpt_account?
      @account.chatgpt_account?
    end

    def config_overrides
      if ollama?
        {
          ollama_api_key: api_key.presence,
          ollama_api_base: api_base.presence
        }
      else
        {
          openai_api_key: api_key.presence,
          openai_api_base: api_base.presence
        }
      end
    end

    def chat_params
      return {} unless ollama?

      { num_ctx: ollama_num_ctx }
    end

    private

    def personal_account_ai?
      @account.personal_ai?
    end

    def ollama?
      provider == "ollama"
    end

    def openai_compatible?
      provider == "openai_compatible"
    end

    def env_api_key
      return ENV["OLLAMA_API_KEY"] if ollama?

      ENV["OPENAI_API_KEY"]
    end

    def env_api_base
      return ENV["OLLAMA_API_BASE"].presence || OLLAMA_DEFAULT_API_BASE if ollama?

      ENV["OPENAI_API_BASE"]
    end

    def env_chat_model
      if ollama?
        ENV["OLLAMA_CHAT_MODEL"].presence || ENV["AI_CHAT_MODEL"].presence || OLLAMA_DEFAULT_CHAT_MODEL
      else
        ENV["AI_CHAT_MODEL"].presence || OPENAI_DEFAULT_CHAT_MODEL
      end
    end

    def env_embedding_model
      if ollama?
        ENV["OLLAMA_EMBEDDING_MODEL"].presence || OLLAMA_DEFAULT_EMBEDDING_MODEL
      else
        ENV["AI_EMBEDDING_MODEL"].presence || OPENAI_DEFAULT_EMBEDDING_MODEL
      end
    end

    def ollama_num_ctx
      value = ENV["OLLAMA_NUM_CTX"].to_i
      value.positive? ? value : OLLAMA_DEFAULT_NUM_CTX
    end
  end
end
