if defined?(RubyLLM)
  RubyLLM.configure do |config|
    openai_api_key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:openai, :api_key).presence
    config.openai_api_key = openai_api_key if openai_api_key.present?
    config.openai_api_base = ENV["OPENAI_API_BASE"] if ENV["OPENAI_API_BASE"].present?
    config.ollama_api_key = ENV["OLLAMA_API_KEY"] if ENV["OLLAMA_API_KEY"].present?
    config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
    config.default_embedding_model = ENV.fetch("AI_EMBEDDING_MODEL", "text-embedding-3-small")
  end
end
