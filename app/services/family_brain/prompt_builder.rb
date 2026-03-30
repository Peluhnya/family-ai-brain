module FamilyBrain
  class PromptBuilder
    SHORT_TERM_LIMIT = 16
    LIFE_LOG_LIMIT = 6
    KNOWLEDGE_LIMIT = 8
    EVENT_LIMIT = 8
    TASK_LIMIT = 8

    def initialize(family:, current_message:)
      @family = family
      @current_message = current_message
    end

    def system_prompt
      retrieval = FamilyBrain::RetrievalService.new(family: @family, query: @current_message.content)

      <<~PROMPT
        You are the Family AI Brain for "#{@family.name}".
        Primary language: Ukrainian, unless the user clearly writes in another language.
        Response style: practical, concise, operational, helpful in everyday family coordination.

        HIGH-LEVEL PIPELINE
        user input -> intent -> context -> memory -> llm -> response -> memory update

        MEMORY LAYERS AVAILABLE IN THIS PROMPT
        1. short_term.ai_interactions
        2. episodic.life_logs
        3. semantic.family_knowledge
        4. calendar.events
        5. procedural.automation_rules
        6. workspace.tasks
        7. family_members

        ACCOUNT CONTEXT
        #{account_context_block}

        FAMILY MEMBERS
        #{family_members_block}

        EPISODIC MEMORY: LIFE LOGS
        #{life_logs_block(retrieval.relevant_life_logs)}

        SEMANTIC MEMORY: FAMILY KNOWLEDGE
        #{family_knowledge_block(retrieval.relevant_knowledge)}

        CALENDAR EVENTS
        #{events_block}

        PROCEDURAL MEMORY: AUTOMATION RULES
        #{automation_rules_block}

        ACTIVE TASKS
        #{tasks_block}

        USE RULES
        - Use short-term memory for immediate conversation continuity.
        - Use life_logs as episodic family memory about real events and routines.
        - Use family_knowledge as stable facts and preferences about the family.
        - Use events as the calendar layer for upcoming schedule, timing, and locations.
        - Use automation_rules as operational rules for what to do and when to do it.
        - Use tasks as the current execution layer: what should be done, by whom, and by when.
        - If information is absent, state that clearly instead of inventing it.
        - Prefer action-oriented answers: plans, reminders, checklists, next steps, clarifying questions.
      PROMPT
    end

    def short_term_messages
      @family.ai_interactions.where.not(id: @current_message.id).order(created_at: :desc).limit(SHORT_TERM_LIMIT).reverse
    end

    private

    def account_context_block
      <<~TEXT.strip
        - account_name: #{@family.account.name}
        - family_name: #{@family.name}
        - timezone: #{@family.timezone.presence || "unknown"}
        - locale: #{@family.locale.presence || "unknown"}
      TEXT
    end

    def family_members_block
      return "- no family members added yet" if @family.family_members.empty?

      @family.family_members.includes(:users).order(:name).map do |member|
        linked_users = member.users.map(&:email).presence || ["no linked user"]
        permissions = Array(member.permissions).presence || ["none"]
        birthdate = member.birthdate&.to_s || "unknown"

        [
          "- name: #{member.name}",
          "  role: #{member.role.presence || 'member'}",
          "  birthdate: #{birthdate}",
          "  linked_users: #{linked_users.join(', ')}",
          "  permissions: #{permissions.join(', ')}"
        ].join("\n")
      end.join("\n")
    end

    def life_logs_block(logs)
      return "- no episodic memory recorded yet" if logs.empty?

      logs.map do |log|
        happened_at = log.happened_at&.strftime("%Y-%m-%d %H:%M") || "unknown"

        [
          "- event_type: #{log.event_type}",
          "  summary: #{log.summary}",
          "  raw_text: #{log.raw_text.presence || 'n/a'}",
          "  importance: #{format('%.2f', log.importance)}",
          "  happened_at: #{happened_at}"
        ].join("\n")
      end.join("\n")
    end

    def family_knowledge_block(knowledge_items)
      return "- no semantic memory recorded yet" if knowledge_items.empty?

      knowledge_items.map do |item|
        [
          "- key: #{item.key}",
          "  value: #{item.value}",
          "  source: #{item.source.presence || 'unknown'}",
          "  confidence: #{format('%.2f', item.confidence)}"
        ].join("\n")
      end.join("\n")
    end

    def automation_rules_block
      rules = @family.automation_rules.active_first.limit(8)
      return "- no automation rules recorded yet" if rules.empty?

      rules.map do |rule|
        [
          "- name: #{rule.name}",
          "  trigger_type: #{rule.trigger_type}",
          "  trigger_config: #{rule.trigger_config.to_json}",
          "  action_type: #{rule.action_type}",
          "  action_config: #{rule.action_config.to_json}",
          "  active: #{rule.active}"
        ].join("\n")
      end.join("\n")
    end

    def events_block
      events = @family.events.upcoming_first.limit(EVENT_LIMIT)
      return "- no calendar events recorded yet" if events.empty?

      events.map do |event|
        [
          "- title: #{event.title}",
          "  start_time: #{event.start_time&.strftime('%Y-%m-%d %H:%M') || 'unknown'}",
          "  end_time: #{event.end_time&.strftime('%Y-%m-%d %H:%M') || 'none'}",
          "  location: #{event.location.presence || 'n/a'}",
          "  source: #{event.source.presence || 'manual'}"
        ].join("\n")
      end.join("\n")
    end

    def tasks_block
      tasks = @family.tasks.open_first.limit(TASK_LIMIT)
      return "- no tasks recorded yet" if tasks.empty?

      tasks.map do |task|
        [
          "- title: #{task.title}",
          "  description: #{task.description.presence || 'n/a'}",
          "  assigned_to: #{task.assignee&.name.presence || 'unassigned'}",
          "  status: #{task.status}",
          "  priority: #{task.priority}",
          "  due_at: #{task.due_at&.strftime('%Y-%m-%d %H:%M') || 'none'}"
        ].join("\n")
      end.join("\n")
    end
  end
end
