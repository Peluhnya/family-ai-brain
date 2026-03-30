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
      llm_client = FamilyBrain::LlmClient.new(account: @family.account)
      return [] unless llm_client.available?

      response = llm_client.with_chat(schema: FACT_SCHEMA) do |chat|
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

  end
end
