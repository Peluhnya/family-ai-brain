module FamilyBrain
  class KnowledgeSyncService
    FACT_SCHEMA = {
      type: "object",
      properties: {
        facts: {
          type: "array",
          items: {
            type: "object",
            properties: {
              key: { type: "string" },
              value: { type: "string" },
              confidence: { type: "number" },
              source: { type: "string" }
            },
            required: %w[key value confidence source],
            additionalProperties: false
          }
        }
      },
      required: ["facts"],
      additionalProperties: false
    }.freeze

    def initialize(family:, text:, source:)
      @family = family
      @text = text.to_s.strip
      @source = source
    end

    def call
      return [] if @text.blank?
      account_ai_config = FamilyBrain::AccountAiConfig.new(account: @family.account)
      return [] unless account_ai_config.available?

      response = with_account_ai_config(account_ai_config) do
        chat = RubyLLM.chat(model: account_ai_config.chat_model, provider: :openai, assume_model_exists: true).with_schema(FACT_SCHEMA)
        chat.ask(extraction_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content : {}

      Array(payload["facts"]).filter_map { |fact| upsert_fact(fact) }
    rescue StandardError
      []
    end

    private

    def extraction_prompt
      <<~PROMPT
        Extract only stable family facts from the text below.
        Ignore temporary requests, conversational filler, and one-off details.
        Return up to 5 facts.
        Keys must be snake_case and reusable.
        Values must be concise factual statements in Ukrainian.
        Confidence must be between 0.0 and 1.0.
        Source should be "#{@source}" unless the text clearly indicates another source.

        Existing family context:
        - family: #{@family.name}
        - account: #{@family.account.name}

        Text:
        #{@text}
      PROMPT
    end

    def upsert_fact(fact)
      key = fact["key"].to_s.strip
      value = fact["value"].to_s.strip
      return if key.blank? || value.blank?

      knowledge = @family.family_knowledge.find_or_initialize_by(key: key)
      knowledge.value = value
      knowledge.source = fact["source"].presence || @source
      knowledge.confidence = normalize_confidence(fact["confidence"])
      knowledge.embedding = FamilyBrain::EmbeddingService.embed("#{key}: #{value}", account: @family.account)
      knowledge.save!
      knowledge
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def normalize_confidence(value)
      numeric = value.to_f
      return 0.7 if numeric.zero? && value.to_s !~ /\A0(\.0+)?\z/

      numeric.clamp(0.0, 1.0)
    end

    def with_account_ai_config(config)
      previous_api_key = RubyLLM.config.openai_api_key
      previous_api_base = RubyLLM.config.openai_api_base

      RubyLLM.config.openai_api_key = config.api_key
      RubyLLM.config.openai_api_base = config.api_base if config.api_base.present?

      yield
    ensure
      RubyLLM.config.openai_api_key = previous_api_key
      RubyLLM.config.openai_api_base = previous_api_base
    end
  end
end
