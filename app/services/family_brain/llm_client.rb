module FamilyBrain
  class LlmClient
    attr_reader :config

    def initialize(account:)
      @config = FamilyBrain::AccountAiConfig.new(account: account)
    end

    def available?
      config.available?
    end

    def with_chat(schema: nil)
      with_config do
        chat = RubyLLM.chat(
          model: config.chat_model,
          provider: config.ruby_llm_provider,
          assume_model_exists: true
        )
        chat = chat.with_params(**config.chat_params) if config.chat_params.any?
        chat = chat.with_schema(schema) if schema
        yield chat
      end
    end

    def embed(text)
      with_config do
        RubyLLM.embed(
          text,
          model: config.embedding_model,
          provider: config.ruby_llm_provider,
          assume_model_exists: true
        )
      end
    end

    private

    def with_config
      previous_values = config.config_overrides.transform_values { nil }

      config.config_overrides.each_key do |key|
        previous_values[key] = RubyLLM.config.public_send(key)
      end

      config.config_overrides.each do |key, value|
        RubyLLM.config.public_send("#{key}=", value)
      end

      yield
    ensure
      previous_values&.each do |key, value|
        RubyLLM.config.public_send("#{key}=", value)
      end
    end
  end
end
