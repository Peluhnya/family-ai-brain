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
              location: { type: "string" },
              source: { type: "string" },
              start_in_days: { type: "integer" },
              duration_hours: { type: "integer" }
            },
            required: %w[title location source start_in_days duration_hours],
            additionalProperties: false
          }
        }
      },
      required: ["events"],
      additionalProperties: false
    }.freeze

    def initialize(family:, text:)
      @family = family
      @text = text.to_s.strip
    end

    def call
      return [] if @text.blank?
      account_ai_config = FamilyBrain::AccountAiConfig.new(account: @family.account)
      return [] unless account_ai_config.available?

      response = with_account_ai_config(account_ai_config) do
        chat = RubyLLM.chat(model: account_ai_config.chat_model, provider: :openai, assume_model_exists: true).with_schema(EVENT_SCHEMA)
        chat.ask(extraction_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content : {}

      Array(payload["events"]).filter_map { |event_payload| create_event(event_payload) }
    rescue StandardError
      []
    end

    private

    def extraction_prompt
      <<~PROMPT
        Extract only explicit family calendar events from the text below.
        Ignore vague plans, tasks, and things without a clear scheduling intent.
        Return up to 3 events.
        Use Ukrainian for title and location.
        source should usually be "chat:auto".
        start_in_days must be 0 if the event is today or timing is immediate, 1 for tomorrow, etc.
        duration_hours must be 1 if no duration is known.

        Text:
        #{@text}
      PROMPT
    end

    def create_event(event_payload)
      title = event_payload["title"].to_s.strip
      return if title.blank?

      start_time = normalize_start_time(event_payload["start_in_days"])
      return if duplicate_event?(title, start_time)

      @family.events.create!(
        title: title,
        location: event_payload["location"].to_s.strip.presence,
        source: event_payload["source"].to_s.strip.presence || "chat:auto",
        start_time: start_time,
        end_time: start_time + normalize_duration(event_payload["duration_hours"]).hours
      )
    rescue ActiveRecord::RecordInvalid
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
