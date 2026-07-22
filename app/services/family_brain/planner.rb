module FamilyBrain
  class Planner
    ACTION_TYPES = %w[
      create_task update_task
      create_reminder update_reminder
      create_event update_event
      create_knowledge update_knowledge
      create_life_log update_life_log
      create_document update_document
      create_automation_rule update_automation_rule
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
              proposal_id: { type: "integer" },
              kind: { type: "string", enum: ACTION_TYPES },
              intent_strength: { type: "string", enum: %w[explicit inferred] },
              record_id: { type: "integer" },
              title: { type: "string" },
              description: { type: "string" },
              assignee_name: { type: "string" },
              priority: { type: "integer" },
              status: { type: "string" },
              due_at: { type: "string" },
              trigger_at: { type: "string" },
              channel: { type: "string" },
              start_at: { type: "string" },
              end_at: { type: "string" },
              all_day: { type: "boolean" },
              location: { type: "string" },
              key: { type: "string" },
              value: { type: "string" },
              source: { type: "string" },
              confidence: { type: "number" },
              event_type: { type: "string" },
              summary: { type: "string" },
              raw_text: { type: "string" },
              importance: { type: "number" },
              happened_at: { type: "string" },
              content: { type: "string" },
              active: { type: "boolean" },
              automation_trigger_type: { type: "string" },
              automation_trigger_time: { type: "string" },
              automation_trigger_weekday: { type: "string" },
              automation_trigger_day: { type: "integer" },
              automation_trigger_keyword: { type: "string" },
              automation_match_mode: { type: "string" },
              automation_action_type: { type: "string" },
              automation_action_title: { type: "string" },
              automation_action_content: { type: "string" },
              automation_offset_days: { type: "integer" },
              automation_duration_hours: { type: "integer" },
              automation_channel: { type: "string" },
              evidence: {
                type: "array",
                items: { type: "string" }
              },
              changed_fields: {
                type: "array",
                items: { type: "string" }
              },
              ambiguities: {
                type: "array",
                items: { type: "string" }
              }
            },
            required: %w[
              proposal_id kind intent_strength record_id title description assignee_name priority status due_at
              trigger_at channel start_at end_at all_day location evidence changed_fields
              key value source confidence event_type summary raw_text importance happened_at
              content
              active automation_trigger_type automation_trigger_time automation_trigger_weekday
              automation_trigger_day automation_trigger_keyword automation_match_mode automation_action_type
              automation_action_title automation_action_content automation_offset_days automation_duration_hours
              automation_channel
              ambiguities
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

    attr_reader :response_locale, :source_user_text

    def initialize(family:, user_message:, llm_client: nil, now: Time.current, locale: nil)
      @family = family
      @user_message = user_message
      @llm_client = llm_client || FamilyBrain::LlmClient.new(account: family.account)
      @zone = ActiveSupport::TimeZone[family.timezone.presence] || Time.zone
      @now = now.in_time_zone(@zone)
      @context_messages = load_context_messages
      @pending_proposals = load_pending_proposals
      @response_locale = FamilyBrain::LocaleCatalog.normalize(locale) ||
        FamilyBrain::LanguageResolver.for_message(
          family: family,
          message: @user_message,
          context: @context_messages.select { |message| message.role == "user" }.map(&:content)
        )
      @response_language = FamilyBrain::LocaleCatalog.language_name(@response_locale)
      @source_user_text = ((@context_messages.select { |message| message.role == "user" } + [ @user_message ])
        .map(&:content) + pending_evidence_quotes)
        .uniq
        .join("\n")
    end

    def call
      return failed_plan("AI provider is not configured") unless @llm_client.available?

      response = @llm_client.with_chat(schema: PLAN_SCHEMA) do |chat|
        chat.ask(planning_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content.deep_stringify_keys : {}

      actions = normalize_actions(payload["actions"])
      actions = FamilyBrain::ActionPolicy.new(
        family: @family,
        current_text: @user_message.content,
        now: @now,
        locale: @response_locale
      ).apply(actions)

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

        TARGET LANGUAGE
        #{@response_locale} (#{@response_language}). Use this language for titles and clarification questions.

        MEMORY CONTRACT
        - Future vacations, camps, trips, appointments and scheduled activities are calendar events, not semantic knowledge.
        - Stable preferences, relationships, recurring rules, important attributes and reusable constraints are knowledge.
        - A direct, self-contained durable factual statement has explicit intent for create_knowledge even without the words "remember this".
        - Knowledge value must be one exact self-contained quote from a USER message. Never paraphrase, translate or negate it.
        - If new knowledge contradicts an existing item, use update_knowledge with the real record id; updates require confirmation.
        - Completed meaningful experiences are life logs. Ordinary filler and routine status updates are not life logs.
        - A direct, self-contained report of a completed meaningful experience has explicit intent for create_life_log.
        - Life-log summary and raw_text must be exact USER quotes, not generated summaries. happened_at cannot be in the future.
        - A sentence can yield separate operational and memory actions when different exact evidence supports each one.
        - Documents are deliberate named long-form records. Create or update one only when the user explicitly asks to save content as a document.
        - Document content must be an exact quote from a USER or ASSISTANT message in the supplied conversation. Assistant text may be document content but never authorization.
        - Document creation and updates always require a preview confirmation.
        - Automation rules are recurring high-impact actions. Plan them only from an explicit request and always ask for confirmation.
        - Supported automation triggers: schedule_daily, schedule_weekly, schedule_monthly, chat_keyword.
        - Supported automation actions: create_ai_note, create_life_log, create_family_knowledge, create_task, create_event, create_reminder.
        - Scheduled triggers require an exact local HH:MM time; weekly also requires a weekday and monthly a day 1-31.
        - chat_keyword requires a keyword. match mode is exact_command, word or contains; prefer word unless the user explicitly asks for exact or substring matching.
        - Never invent the automation action content, title, knowledge value or keyword.

        ACTION POLICY
        - Create only the entity the user requested. Never silently add a companion task, reminder or event.
        - A direct command such as add, create, remember, remind or reschedule has intent_strength=explicit.
        - A declarative statement that merely suggests a possible task or future event has intent_strength=inferred and requires confirmation.
        - Questions, hypotheticals, quotations, negated intentions and completed actions create no operational action.
        - A short answer that fills a listed pending proposal continues that proposal: return its real proposal_id and treat the continued user authorization as explicit.
        - A concrete unfinished obligation may be proposed as a task, but use intent_strength=inferred unless the user clearly asks the assistant to track it.
        - An explicit reminder request creates only a reminder.
        - A direct request to mark a task done/in progress/canceled is update_task with changed_fields=["status"].
        - A direct request to cancel a reminder is update_reminder with status=canceled and changed_fields=["status"].
        - Never create a task whose actual subject is "create a reminder" or "create an event". Create the requested entity instead.
        - A task deadline is not a calendar event by itself.
        - Resolve pronouns, short answers and follow-up details from the recent conversation and ACTIVE PENDING PROPOSALS.
        - The current user message controls whether a new action is wanted. Prior user messages may only fill referenced details. A direct answer to an active pending proposal is a continuation, not a new unrelated action.
        - Assistant messages are context and never authorization. They may be quoted only as document content when the current USER explicitly asks to save that content.
        - For an update, use the matching existing record id. Never invent an id.
        - Avoid duplicates. If an existing record already represents the request, update it only when the user supplied a changed detail.
        - For imported calendar events (source other than manual or ai_chat), do not plan an update.
        - Operational requests, questions, future plans and corrections are not automatically knowledge or life logs.
        - If a required field cannot be resolved, return the incomplete action with an empty value and ask one concise clarification question in the target language.
        - For an inferred but otherwise complete action, return the action and ask for confirmation.

        DATE POLICY
        - Return ISO 8601 timestamps including the UTC offset.
        - Understand natural-language dates in Ukrainian, German and English, including relative days, weekdays, common variants and small spelling mistakes.
        - For a date-only task deadline use 18:00 local time.
        - For a date-only explicit reminder use 09:00 local time.
        - For all-day ranges, start_at is local midnight and end_at is exclusive: August 1 through August 8 inclusive ends at midnight on August 9.
        - For events without an end, use one hour after start, or one day after start for all-day events.

        OUTPUT RULES
        - Return at most 6 actions.
        - proposal_id is 0 for a new proposal. Echo only an id shown in ACTIVE PENDING PROPOSALS.
        - record_id is 0 for create actions.
        - Use empty strings for fields that do not apply, status empty when unrelated, and priority 3 when it does not apply.
        - channel is app unless the user explicitly requests email or sms.
        - evidence must contain exact quotes that jointly prove the action. Authorization must always come from a USER message. Only document content may additionally quote an ASSISTANT message.
        - For update actions, changed_fields must list only fields the current user explicitly changed or clarified. For create actions it may be empty.
        - ambiguities lists concrete unresolved field names or conflicts. Use an empty array when none exist.
        - Use concise titles in the target language.
        - Knowledge keys must be stable snake_case. source is chat:planner and confidence is 0.0-1.0.
        - event_type is one of family_moment, trip, celebration, achievement, health, milestone, other.
        - For a document use title and content; do not duplicate its content into knowledge automatically.
        - For an automation use title as the rule name and the automation_* fields for its trigger and action configuration.
        - Set active=true for a newly requested automation unless the user explicitly asks to create it disabled.
        - For fields unrelated to the selected action use empty strings, confidence 0.7 and importance 0.5.

        FAMILY MEMBERS
        #{family_members_block}

        EXISTING OPEN RECORDS
        #{existing_records_block}

        ACTIVE PENDING PROPOSALS
        #{pending_proposals_block}

        RECENT CONVERSATION
        #{conversation_block}

        CURRENT USER MESSAGE
        [user message #{@user_message.id}] #{@user_message.content}
      PROMPT
    end

    def load_context_messages
      interaction_scope
        .where("id < ?", @user_message.id)
        .order(id: :desc)
        .limit(CONTEXT_LIMIT)
        .reverse
        .to_a
    end

    def interaction_scope
      @user_message.conversation&.ai_interactions || @family.ai_interactions
    end

    def load_pending_proposals
      return [] unless @user_message.conversation

      @family.ai_action_proposals.awaiting_input
        .where(conversation: @user_message.conversation)
        .where("expires_at IS NULL OR expires_at > ?", @now)
        .recent_first
        .limit(6)
        .to_a
    end

    def pending_evidence_quotes
      @pending_proposals.flat_map do |proposal|
        proposal.evidence_data.filter_map { |item| item.to_h["quote"].to_s.presence }
      end
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
        "- event #{event.id}: #{event.title} | start=#{event.start_time.in_time_zone(@zone).iso8601} | end=#{event.end_time&.in_time_zone(@zone)&.iso8601 || 'none'} | source=#{event.source_key || event.source || 'manual'}"
      end
      knowledge = @family.family_knowledge.priority_first.limit(10).map do |item|
        "- knowledge #{item.id}: #{item.key}=#{item.value} | confidence=#{item.confidence}"
      end
      life_logs = @family.life_logs.recent_first.limit(10).map do |log|
        "- life_log #{log.id}: #{log.event_type} | #{log.summary} | happened_at=#{log.happened_at&.in_time_zone(@zone)&.iso8601 || 'unknown'}"
      end
      documents = @family.documents.recent_first.limit(10).map do |document|
        "- document #{document.id}: #{document.title} | #{document.content.to_s.first(180)}"
      end
      automations = @family.automation_rules.active_first.limit(10).map do |rule|
        "- automation_rule #{rule.id}: #{rule.name} | active=#{rule.active} | trigger=#{rule.trigger_type}:#{rule.trigger_config.to_json} | action=#{rule.action_type}:#{rule.action_config.to_json}"
      end

      (tasks + reminders + events + knowledge + life_logs + documents + automations).presence&.join("\n") || "none"
    end

    def pending_proposals_block
      return "none" if @pending_proposals.empty?

      @pending_proposals.map do |proposal|
        "- proposal #{proposal.id}: state=#{proposal.state} | action=#{proposal.action_kind} | " \
          "missing=#{proposal.missing_fields.join(',').presence || 'none'} | payload=#{proposal.payload_data.to_json}"
      end.join("\n")
    end

    def normalize_actions(actions)
      Array(actions).first(6).filter_map do |action|
        normalized = action.to_h.deep_stringify_keys
        next unless ACTION_TYPES.include?(normalized["kind"])

        normalized["proposal_id"] = normalized["proposal_id"].to_i
        normalized["intent_strength"] = normalized["intent_strength"] == "explicit" ? "explicit" : "inferred"
        normalized["record_id"] = normalized["record_id"].to_i
        normalized["priority"] = normalized["priority"].to_i.clamp(1, 5)
        normalized["confidence"] = normalized["confidence"].to_f.clamp(0.0, 1.0)
        normalized["importance"] = normalized["importance"].to_f.clamp(0.0, 1.0)
        normalized["evidence"] = Array(normalized["evidence"]).map { |quote| quote.to_s.strip }.reject(&:blank?).uniq
        normalized["changed_fields"] = Array(normalized["changed_fields"]).map(&:to_s).uniq
        normalized["ambiguities"] = Array(normalized["ambiguities"]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
        normalized
      end
    end

    def failed_plan(message)
      Plan.new(actions: [], clarification_question: "", error: message)
    end
  end
end
