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
              evidence: { type: "string" },
              channel: { type: "string" },
              trigger_in_days: { type: "integer" }
            },
            required: %w[title evidence channel trigger_in_days],
            additionalProperties: false
          }
        }
      },
      required: [ "reminders" ],
      additionalProperties: false
    }.freeze

    def initialize(family:, text:)
      @family = family
      @text = text.to_s.strip
      @locale = FamilyBrain::LanguageResolver.resolve(text: @text, fallback: family.locale)
    end

    def call
      return [] if @text.blank?
      return [] unless FamilyBrain::GroundedExtraction.reminder_intent?(@text)
      llm_client = FamilyBrain::LlmClient.new(account: @family.account)
      return [] unless llm_client.available?

      response = llm_client.with_chat(schema: REMINDER_SCHEMA) do |chat|
        chat.ask(extraction_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content : {}

      Array(payload["reminders"]).filter_map { |reminder_payload| create_reminder(reminder_payload) }
    rescue StandardError => error
      Rails.logger.error("family_brain_legacy_reminder_sync_failed family_id=#{@family.id} error=#{error.class}: #{error.message}")
      []
    end

    private

    def extraction_prompt
      <<~PROMPT
        Extract only explicit reminder requests directly stated by the user.
        Ignore tasks, calendar events, vague ideas, and assistant suggestions.
        Do not invent reminders. If the user did not ask to be reminded, return an empty list.
        For each reminder, include an evidence field with the exact short quote from the user's text that proves it is a reminder request.
        Return up to 3 reminders.
        Use #{FamilyBrain::LocaleCatalog.language_name(@locale)} (#{@locale}) for reminder titles.
        channel must be one of: app, email, sms. Prefer app unless the text clearly says otherwise.
        trigger_in_days must be 0 if the reminder is for today or immediate, 1 for tomorrow, etc.

        Text:
        #{@text}
      PROMPT
    end

    def create_reminder(reminder_payload)
      title = reminder_payload["title"].to_s.strip
      evidence = reminder_payload["evidence"].to_s.strip
      return if title.blank?
      return unless FamilyBrain::GroundedExtraction.meaningful_phrase?(title)
      return unless FamilyBrain::GroundedExtraction.evidence_present?(@text, evidence)
      return unless FamilyBrain::GroundedExtraction.title_grounded_in_evidence?(title, evidence)
      return unless FamilyBrain::GroundedExtraction.reminder_intent?(evidence)
      return if duplicate_active_reminder?(title)

      @family.reminders.create!(
        title: title,
        trigger_at: normalize_trigger_at(reminder_payload["trigger_in_days"]),
        channel: normalize_channel(reminder_payload["channel"]),
        status: "pending"
      )
    rescue ActiveRecord::RecordInvalid => error
      Rails.logger.warn("family_brain_legacy_reminder_rejected family_id=#{@family.id} error=#{error.record.errors.full_messages.join(', ')}")
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
  end
end
