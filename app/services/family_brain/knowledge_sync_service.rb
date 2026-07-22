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
              evidence: { type: "string" },
              confidence: { type: "number" },
              source: { type: "string" }
            },
            required: %w[key value evidence confidence source],
            additionalProperties: false
          }
        }
      },
      required: [ "facts" ],
      additionalProperties: false
    }.freeze

    def initialize(family:, text:, source:, now: Time.current, llm_client: nil, embedding_service: FamilyBrain::EmbeddingService)
      @family = family
      @text = text.to_s.strip
      @source = source
      @zone = ActiveSupport::TimeZone[family.timezone.presence] || Time.zone
      @now = now.in_time_zone(@zone)
      @date_parser = FamilyBrain::UkrainianDateParser.new(reference_time: @now, timezone: @zone.tzinfo.name)
      @llm_client = llm_client
      @embedding_service = embedding_service
    end

    def call
      return [] if @text.blank?
      llm_client = @llm_client || FamilyBrain::LlmClient.new(account: @family.account)
      return [] unless llm_client.available?

      response = llm_client.with_chat(schema: FACT_SCHEMA) do |chat|
        chat.ask(extraction_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content : {}

      Array(payload["facts"]).filter_map { |fact| upsert_fact(fact) }
    rescue StandardError => error
      Rails.logger.error("family_brain_knowledge_sync_failed family_id=#{@family.id} error=#{error.class}: #{error.message}")
      []
    end

    private

    def extraction_prompt
      <<~PROMPT
        Extract only stable semantic family facts explicitly stated by the user.
        Stable facts include durable preferences, relationships, recurring rules, important attributes and reusable constraints.
        Do not extract future or past calendar occurrences, vacations, camps, trips, appointments, deadlines, tasks, reminders, one-off experiences, or assistant suggestions.
        A completed experience belongs to episodic memory. Only a durable conclusion explicitly stated by the user belongs here, for example "ми любимо ходити в гори".
        Return up to 5 facts.
        Keys must be snake_case and reusable.
        Values must be concise factual statements in Ukrainian.
        Evidence must be an exact short quote from the supplied text. Do not paraphrase evidence.
        Confidence must be between 0.0 and 1.0.
        Source should be "#{@source}" unless the text clearly indicates another source.

        USER TEXT:
        #{@text}
      PROMPT
    end

    def upsert_fact(fact)
      key = fact["key"].to_s.strip
      value = fact["value"].to_s.strip
      evidence = fact["evidence"].to_s.strip
      return if key.blank? || value.blank?
      return unless FamilyBrain::GroundedExtraction.evidence_present?(@text, evidence)
      return if time_bounded_occurrence?(evidence)

      knowledge = @family.family_knowledge.find_or_initialize_by(key: key)
      knowledge.value = value
      knowledge.source = fact["source"].presence || @source
      knowledge.confidence = normalize_confidence(fact["confidence"])
      knowledge.embedding = @embedding_service.embed("#{key}: #{value}", account: @family.account)
      knowledge.save!
      knowledge
    rescue ActiveRecord::RecordInvalid => error
      Rails.logger.warn("family_brain_knowledge_rejected family_id=#{@family.id} error=#{error.record.errors.full_messages.join(', ')}")
      nil
    end

    def normalize_confidence(value)
      numeric = value.to_f
      return 0.7 if numeric.zero? && value.to_s !~ /\A0(\.0+)?\z/

      numeric.clamp(0.0, 1.0)
    end

    def time_bounded_occurrence?(evidence)
      return false unless FamilyBrain::GroundedExtraction.temporal_reference?(evidence)
      return false if evidence.match?(/\b(завжди|зазвичай|щороку|кожн(?:ого|ої|і|у)|народив|народила|день народження)\b/i)

      @date_parser.parse_range(evidence).present? || @date_parser.parse_datetime(evidence, default_hour: 0).present?
    end
  end
end
