module FamilyBrain
  class LifeLogSyncService
    LIFE_LOG_SCHEMA = {
      type: "object",
      properties: {
        life_logs: {
          type: "array",
          items: {
            type: "object",
            properties: {
              event_type: { type: "string" },
              summary: { type: "string" },
              evidence: { type: "string" },
              importance: { type: "number" },
              happened_at: { type: "string" }
            },
            required: %w[event_type summary evidence importance happened_at],
            additionalProperties: false
          }
        }
      },
      required: [ "life_logs" ],
      additionalProperties: false
    }.freeze

    def initialize(family:, text:, now: Time.current, llm_client: nil, embedding_service: FamilyBrain::EmbeddingService)
      @family = family
      @text = text.to_s.strip
      @zone = ActiveSupport::TimeZone[family.timezone.presence] || Time.zone
      @now = now.in_time_zone(@zone)
      @locale = FamilyBrain::LanguageResolver.resolve(text: @text, fallback: family.locale)
      @date_parser = FamilyBrain::TemporalParser.new(
        reference_time: @now,
        timezone: @zone.tzinfo.name,
        locale: @locale
      )
      @llm_client = llm_client
      @embedding_service = embedding_service
    end

    def call
      return [] if @text.blank?

      llm_client = @llm_client || FamilyBrain::LlmClient.new(account: @family.account)
      return [] unless llm_client.available?

      response = llm_client.with_chat(schema: LIFE_LOG_SCHEMA) do |chat|
        chat.ask(extraction_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content.deep_stringify_keys : {}

      Array(payload["life_logs"]).filter_map { |entry| create_life_log(entry) }
    rescue StandardError => error
      Rails.logger.error("family_brain_life_log_sync_failed family_id=#{@family.id} error=#{error.class}: #{error.message}")
      []
    end

    private

    def extraction_prompt
      <<~PROMPT
        Extract only meaningful completed personal or family experiences explicitly reported by the user.
        Examples: a completed vacation, celebration, achievement, memorable outing, illness episode or important family moment.
        Do not extract future plans, calendar events, tasks, reminders, questions, intentions or assistant statements.
        Do not extract ordinary conversational filler.
        Return at most 3 episodic memories.
        Use concise #{FamilyBrain::LocaleCatalog.language_name(@locale)} (#{@locale}) for event_type and summary.
        Evidence must be an exact quote from USER TEXT.
        happened_at must be ISO 8601 with offset and cannot be in the future.
        If the experience is clearly completed but no exact time is stated, use CURRENT TIME.
        importance must be between 0.0 and 1.0.

        CURRENT TIME
        #{@now.iso8601} (timezone: #{@zone.tzinfo.name})

        USER TEXT
        #{@text}
      PROMPT
    end

    def create_life_log(entry)
      evidence = entry["evidence"].to_s.strip
      summary = entry["summary"].to_s.strip
      event_type = entry["event_type"].to_s.strip
      return unless FamilyBrain::GroundedExtraction.evidence_present?(@text, evidence)
      return unless FamilyBrain::GroundedExtraction.meaningful_phrase?(summary)
      return if future_experience?(evidence)

      happened_at = @date_parser.parse_datetime(entry["happened_at"], default_hour: @now.hour) || @now
      return if happened_at > @now + 5.minutes
      return if duplicate?(summary, happened_at)

      @family.life_logs.create!(
        event_type: event_type.presence || "family_moment",
        summary: summary,
        raw_text: evidence,
        importance: entry["importance"].to_f.clamp(0.0, 1.0),
        happened_at: happened_at,
        embedding: @embedding_service.embed([ event_type, summary, evidence ].join("\n"), account: @family.account)
      )
    rescue ActiveRecord::RecordInvalid => error
      Rails.logger.warn("family_brain_life_log_rejected family_id=#{@family.id} error=#{error.record.errors.full_messages.join(', ')}")
      nil
    end

    def duplicate?(summary, happened_at)
      normalized = FamilyBrain::GroundedExtraction.normalize_text(summary)
      @family.life_logs.where(happened_at: (happened_at - 1.day)..(happened_at + 1.day)).detect do |life_log|
        FamilyBrain::GroundedExtraction.normalize_text(life_log.summary) == normalized
      end.present?
    end

    def future_experience?(evidence)
      return false unless FamilyBrain::GroundedExtraction.future_intent?(evidence)

      range = @date_parser.parse_range(evidence)
      parsed_time = range&.first || @date_parser.parse_datetime(evidence, default_hour: 0)
      parsed_time.blank? || parsed_time >= @now.beginning_of_day
    end
  end
end
