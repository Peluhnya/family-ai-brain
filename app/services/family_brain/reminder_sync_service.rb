module FamilyBrain
  class ReminderSyncService
    REMINDER_SCHEMA = {
      type: "object",
      properties: {
        reminders: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string" },
              channel: { type: "string" },
              trigger_in_days: { type: "integer" }
            },
            required: %w[title channel trigger_in_days],
            additionalProperties: false
          }
        }
      },
      required: ["reminders"],
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
        chat = RubyLLM.chat(model: account_ai_config.chat_model, provider: :openai, assume_model_exists: true).with_schema(REMINDER_SCHEMA)
        chat.ask(extraction_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content : {}

      Array(payload["reminders"]).filter_map { |reminder_payload| create_reminder(reminder_payload) }
    rescue StandardError
      []
    end

    private

    def extraction_prompt
      <<~PROMPT
        Extract only explicit reminder requests from the text below.
        Ignore tasks, calendar events, and vague ideas.
        Return up to 3 reminders.
        Use Ukrainian for reminder titles.
        channel must be one of: app, email, sms. Prefer app unless the text clearly says otherwise.
        trigger_in_days must be 0 if the reminder is for today or immediate, 1 for tomorrow, etc.

        Text:
        #{@text}
      PROMPT
    end

    def create_reminder(reminder_payload)
      title = reminder_payload["title"].to_s.strip
      return if title.blank?
      return if duplicate_active_reminder?(title)

      @family.reminders.create!(
        title: title,
        trigger_at: normalize_trigger_at(reminder_payload["trigger_in_days"]),
        channel: normalize_channel(reminder_payload["channel"]),
        status: "pending"
      )
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def duplicate_active_reminder?(title)
      @family.reminders.active.where(title: title).exists?
    end

    def normalize_channel(value)
      channel = value.to_s.strip
      Reminder::CHANNELS.include?(channel) ? channel : "app"
    end

    def normalize_trigger_at(value)
      days = value.to_i
      days = 0 if days.negative?
      (days.days.from_now).change(min: 0)
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
