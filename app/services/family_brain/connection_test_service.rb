module FamilyBrain
  class ConnectionTestService
    def initialize(account:)
      @account = account
      @config = FamilyBrain::AccountAiConfig.new(account: account)
    end

    def call
      return failure("AI is not configured for this account.") unless @config.available?

      with_account_ai_config do
        response = RubyLLM.chat(model: @config.chat_model, provider: :openai, assume_model_exists: true)
          .ask("Reply with exactly: OK")

        return success("Connection OK via #{@config.label}. Response: #{response.content.to_s.strip.first(80)}")
      end
    rescue StandardError => e
      failure("Connection failed: #{e.message}")
    end

    private

    def with_account_ai_config
      previous_api_key = RubyLLM.config.openai_api_key
      previous_api_base = RubyLLM.config.openai_api_base

      RubyLLM.config.openai_api_key = @config.api_key
      RubyLLM.config.openai_api_base = @config.api_base if @config.api_base.present?

      yield
    ensure
      RubyLLM.config.openai_api_key = previous_api_key
      RubyLLM.config.openai_api_base = previous_api_base
    end

    def success(message)
      { ok: true, message: message }
    end

    def failure(message)
      { ok: false, message: message }
    end
  end
end
