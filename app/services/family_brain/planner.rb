module FamilyBrain
  class Planner
    ACTION_TYPES = %w[
      create_task update_task
      create_reminder update_reminder
      create_event update_event
    ].freeze
    CONTEXT_LIMIT = 10

    PLAN_SCHEMA = {
      type: "object",
      properties: {
        actions: {
          type: "array",
          items: {
            type: "object",
            properties: {
              kind: { type: "string", enum: ACTION_TYPES },
              record_id: { type: "integer" },
              title: { type: "string" },
              description: { type: "string" },
              assignee_name: { type: "string" },
              priority: { type: "integer" },
              due_at: { type: "string" },
              trigger_at: { type: "string" },
              channel: { type: "string" },
              start_at: { type: "string" },
              end_at: { type: "string" },
              all_day: { type: "boolean" },
              location: { type: "string" },
              evidence: {
                type: "array",
                items: { type: "string" }
              },
              changed_fields: {
                type: "array",
                items: { type: "string" }
              }
            },
            required: %w[
              kind record_id title description assignee_name priority due_at
              trigger_at channel start_at end_at all_day location evidence changed_fields
            ],
            additionalProperties: false
          }
        },
        clarification_question: { type: "string" }
      },
      required: %w[actions clarification_question],
      additionalProperties: false
    }.freeze

    Plan = Data.define(:actions, :clarification_question, :error) do
      def clarification_required?
        clarification_question.present?
      end

      def failed?
        error.present?
      end
    end

    attr_reader :source_user_text

    def initialize(family:, user_message:, llm_client: nil, now: Time.current)
      @family = family
      @user_message = user_message
      @llm_client = llm_client || FamilyBrain::LlmClient.new(account: family.account)
      @zone = ActiveSupport::TimeZone[family.timezone.presence] || Time.zone
      @now = now.in_time_zone(@zone)
      @context_messages = load_context_messages
      @source_user_text = (@context_messages.select { |message| message.role == "user" } + [ @user_message ])
        .map(&:content)
        .join("\n")
    end

    def call
      return failed_plan("AI provider is not configured") unless @llm_client.available?

      response = @llm_client.with_chat(schema: PLAN_SCHEMA) do |chat|
        chat.ask(planning_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content.deep_stringify_keys : {}

      actions = normalize_actions(payload["actions"])
      actions = FamilyBrain::ActionPolicy.new(family: @family, current_text: @user_message.content, now: @now).apply(actions)

      Plan.new(
        actions: actions,
        clarification_question: payload["clarification_question"].to_s.strip,
        error: nil
      )
    rescue StandardError => error
      Rails.logger.error("family_brain_planner_failed family_id=#{@family.id} interaction_id=#{@user_message.id} error=#{error.class}: #{error.message}")
      failed_plan(error.message)
    end

    private

    def planning_prompt
      <<~PROMPT
        You are an action planner for a family assistant. Plan database actions; do not write the chat reply.

        CURRENT TIME
        #{@now.iso8601} (timezone: #{@zone.tzinfo.name})

        MEMORY CONTRACT
        - Future vacations, camps, trips, appointments and scheduled activities are calendar events, not semantic knowledge.
        - Completed experiences belong to episodic memory and are processed separately after the turn.
        - Do not create knowledge actions here.

        ACTION POLICY
        - A concrete unfinished obligation creates a task.
        - A concrete obligation with a deadline creates both a task and a reminder, unless the user explicitly asks for only one of them.
        - An important future family event creates an event. Also create a reminder for the previous day at 18:00 unless the user opts out or specifies another reminder time.
        - An explicit reminder request creates a reminder. If its subject is an actionable unfinished obligation, also create a task unless the user says "only a reminder".
        - Never create a task whose actual subject is "create a reminder" or "create an event". Create the requested entity instead.
        - A task deadline is not a calendar event by itself.
        - Resolve pronouns, short answers and follow-up details from the recent conversation. The current user message controls whether an action is wanted; prior user messages may only fill referenced details.
        - Assistant messages are context, never evidence and never authorization.
        - For an update, use the matching existing record id. Never invent an id.
        - Avoid duplicates. If an existing record already represents the request, update it only when the user supplied a changed detail.
        - If a required subject or date cannot be resolved, return no incomplete action and ask one concise Ukrainian clarification question.

        DATE POLICY
        - Return ISO 8601 timestamps including the UTC offset.
        - Understand Ukrainian month names, relative days, weekdays, apostrophe variants and small spelling mistakes.
        - For a date-only task deadline use 18:00 local time.
        - For a date-only explicit reminder use 09:00 local time.
        - For all-day ranges, start_at is local midnight and end_at is exclusive: "1-8 серпня включно" ends at midnight on 9 August.
        - For events without an end, use one hour after start, or one day after start for all-day events.

        OUTPUT RULES
        - Return at most 6 actions.
        - record_id is 0 for create actions.
        - Use empty strings for fields that do not apply and priority 3 when it does not apply.
        - channel is app unless the user explicitly requests email or sms.
        - evidence must contain exact quotes from USER messages that jointly prove the action. Do not paraphrase evidence.
        - For update actions, changed_fields must list only fields the current user explicitly changed or clarified. For create actions it may be empty.
        - Use concise Ukrainian titles.

        FAMILY MEMBERS
        #{family_members_block}

        EXISTING OPEN RECORDS
        #{existing_records_block}

        RECENT CONVERSATION
        #{conversation_block}

        CURRENT USER MESSAGE
        [user message #{@user_message.id}] #{@user_message.content}
      PROMPT
    end

    def load_context_messages
      @family.ai_interactions
        .where("id < ?", @user_message.id)
        .order(id: :desc)
        .limit(CONTEXT_LIMIT)
        .reverse
        .to_a
    end

    def conversation_block
      return "none" if @context_messages.empty?

      @context_messages.map { |message| "[#{message.role} message #{message.id}] #{message.content}" }.join("\n")
    end

    def family_members_block
      members = @family.family_members.order(:name).to_a
      return "none" if members.empty?

      members.map { |member| "- #{member.id}: #{member.name}" }.join("\n")
    end

    def existing_records_block
      tasks = @family.tasks.active.order(created_at: :desc).limit(10).map do |task|
        "- task #{task.id}: #{task.title} | due=#{task.due_at&.in_time_zone(@zone)&.iso8601 || 'none'}"
      end
      reminders = @family.reminders.active.order(created_at: :desc).limit(10).map do |reminder|
        "- reminder #{reminder.id}: #{reminder.title} | trigger=#{reminder.trigger_at.in_time_zone(@zone).iso8601}"
      end
      events = @family.events.where("end_time IS NULL OR end_time >= ?", @now.beginning_of_day).order(created_at: :desc).limit(10).map do |event|
        "- event #{event.id}: #{event.title} | start=#{event.start_time.in_time_zone(@zone).iso8601} | end=#{event.end_time&.in_time_zone(@zone)&.iso8601 || 'none'}"
      end

      (tasks + reminders + events).presence&.join("\n") || "none"
    end

    def normalize_actions(actions)
      Array(actions).first(6).filter_map do |action|
        normalized = action.to_h.deep_stringify_keys
        next unless ACTION_TYPES.include?(normalized["kind"])

        normalized["record_id"] = normalized["record_id"].to_i
        normalized["priority"] = normalized["priority"].to_i.clamp(1, 5)
        normalized["evidence"] = Array(normalized["evidence"]).map { |quote| quote.to_s.strip }.reject(&:blank?).uniq
        normalized["changed_fields"] = Array(normalized["changed_fields"]).map(&:to_s).uniq
        normalized
      end
    end

    def failed_plan(message)
      Plan.new(actions: [], clarification_question: "", error: message)
    end
  end
end
