if defined?(RubyLLM)
  RubyLLM.configure do |config|
    config.openai_api_key = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"].present?
    config.default_embedding_model = ENV.fetch("AI_EMBEDDING_MODEL", "text-embedding-3-small")
  end
end
