module FamilyBrain
  class EmbeddingService
    def self.embed(text, account:)
      return if text.blank?
      config = FamilyBrain::AccountAiConfig.new(account: account)
      return unless config.available?

      previous_api_key = RubyLLM.config.openai_api_key
      previous_api_base = RubyLLM.config.openai_api_base

      RubyLLM.config.openai_api_key = config.api_key
      RubyLLM.config.openai_api_base = config.api_base if config.api_base.present?

      embedding = RubyLLM.embed(text, model: config.embedding_model, provider: :openai, assume_model_exists: true)
      vector = embedding.vectors

      return vector if vector.is_a?(Array) && vector.first.is_a?(Float)
      return vector.first if vector.is_a?(Array) && vector.first.is_a?(Array)

      nil
    rescue StandardError
      nil
    ensure
      RubyLLM.config.openai_api_key = previous_api_key if defined?(previous_api_key)
      RubyLLM.config.openai_api_base = previous_api_base if defined?(previous_api_base)
    end
  end
end
