module FamilyBrain
  class EventSyncService
    EVENT_SCHEMA = {
      type: "object",
      properties: {
        events: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string" },
              evidence: { type: "string" },
              location: { type: "string" },
              source: { type: "string" },
              start_in_days: { type: "integer" },
              duration_hours: { type: "integer" }
            },
            required: %w[title evidence location source start_in_days duration_hours],
            additionalProperties: false
          }
        }
      },
      required: [ "events" ],
      additionalProperties: false
    }.freeze

    def initialize(family:, text:)
      @family = family
      @text = text.to_s.strip
    end

    def call
      return [] if @text.blank?
      return [] unless FamilyBrain::GroundedExtraction.temporal_reference?(@text)
      llm_client = FamilyBrain::LlmClient.new(account: @family.account)
      return [] unless llm_client.available?

      response = llm_client.with_chat(schema: EVENT_SCHEMA) do |chat|
        chat.ask(extraction_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content : {}

      Array(payload["events"]).filter_map { |event_payload| create_event(event_payload) }
    rescue StandardError => error
      Rails.logger.error("family_brain_legacy_event_sync_failed family_id=#{@family.id} error=#{error.class}: #{error.message}")
      []
    end

    private

    def extraction_prompt
      <<~PROMPT
        Extract only explicit family calendar events directly grounded in the user's text.
        Ignore vague plans, tasks, brainstorming, and anything without a clear scheduling intent.
        Do not invent events from summaries or suggestions. If date/time intent is unclear, return an empty list.
        For each event, include an evidence field with the exact short quote from the user's text that proves both the event and its timing.
        Return up to 3 events.
        Use Ukrainian for title and location.
        source should usually be "ai_chat".
        start_in_days must be 0 if the event is today or timing is immediate, 1 for tomorrow, etc.
        duration_hours must be 1 if no duration is known.

        Text:
        #{@text}
      PROMPT
    end

    def create_event(event_payload)
      title = event_payload["title"].to_s.strip
      evidence = event_payload["evidence"].to_s.strip
      return if title.blank?
      return unless FamilyBrain::GroundedExtraction.meaningful_phrase?(title)
      return unless FamilyBrain::GroundedExtraction.evidence_present?(@text, evidence)
      return unless FamilyBrain::GroundedExtraction.title_grounded_in_evidence?(title, evidence)
      return unless FamilyBrain::GroundedExtraction.temporal_reference?(evidence)

      start_time = normalize_start_time(event_payload["start_in_days"])
      return if duplicate_event?(title, start_time)

      @family.events.create!(
        title: title,
        location: event_payload["location"].to_s.strip.presence,
        source: event_payload["source"].to_s.strip.presence || "ai_chat",
        start_time: start_time,
        end_time: start_time + normalize_duration(event_payload["duration_hours"]).hours
      )
    rescue ActiveRecord::RecordInvalid => error
      Rails.logger.warn("family_brain_legacy_event_rejected family_id=#{@family.id} error=#{error.record.errors.full_messages.join(', ')}")
      nil
    end

    def duplicate_event?(title, start_time)
      @family.events.where(title: title, start_time: start_time).exists?
    end

    def normalize_start_time(value)
      days = value.to_i
      days = 0 if days.negative?

      (days.days.from_now).change(min: 0)
    end

    def normalize_duration(value)
      hours = value.to_i
      return 1 if hours <= 0

      hours.clamp(1, 24)
    end
  end
end
