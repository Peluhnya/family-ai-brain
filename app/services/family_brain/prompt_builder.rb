module FamilyBrain
  class PromptBuilder
    PROMPT_VERSION = "v2_compact".freeze
    SHORT_TERM_LIMIT = 8
    LIFE_LOG_LIMIT = 4
    KNOWLEDGE_LIMIT = 5
    DOCUMENT_LIMIT = 3
    EVENT_LIMIT = 4
    REMINDER_LIMIT = 4
    TASK_LIMIT = 5
    AUTOMATION_LIMIT = 4

    def initialize(family:, current_message:)
      @family = family
      @current_message = current_message
    end

    def system_prompt
      prompt_payload[:prompt]
    end

    def short_term_messages
      @family.ai_interactions.where.not(id: @current_message.id).order(created_at: :desc).limit(SHORT_TERM_LIMIT).reverse
    end

    def prompt_metrics
      prompt_payload[:metrics]
    end

    def prompt_version
      PROMPT_VERSION
    end

    private

    def account_context_block
      [
        "account=#{@family.account.name}",
        "family=#{@family.name}",
        "timezone=#{@family.timezone.presence || 'unknown'}",
        "locale=#{@family.locale.presence || 'unknown'}"
      ].join(" | ")
    end

    def family_members_block
      return "none" if @family.family_members.empty?

      @family.family_members.includes(:users).order(:name).map do |member|
        linked_users = member.users.map(&:email).presence || [ "no linked user" ]
        details = [
          member.name,
          member.role.presence || "member"
        ]
        details << member.birthdate.to_s if member.birthdate.present?
        details << "users: #{linked_users.join(', ')}"

        "- #{details.join(' | ')}"
      end.join("\n")
    end

    def life_logs_block(logs)
      return nil if logs.empty?

      logs.map do |log|
        happened_at = log.happened_at&.strftime("%Y-%m-%d %H:%M") || "unknown"
        "- #{log.event_type} | #{truncate_text(log.summary, 180)} | at: #{happened_at} | importance: #{format('%.2f', log.importance)}"
      end.join("\n")
    end

    def family_knowledge_block(knowledge_items)
      return nil if knowledge_items.empty?

      knowledge_items.map do |item|
        "- #{item.key}: #{truncate_text(item.value, 180)} (src: #{item.source.presence || 'unknown'}, conf: #{format('%.2f', item.confidence)})"
      end.join("\n")
    end

    def documents_block(documents)
      return nil if documents.empty?

      documents.map do |document|
        "- #{document.title}: #{truncate_text(document.content, 320)}"
      end.join("\n")
    end

    def automation_rules_block(rules)
      return nil if rules.empty?

      rules.map do |rule|
        trigger_summary = summarize_json(rule.trigger_config)
        action_summary = summarize_json(rule.action_config)
        "- #{rule.name} | trigger: #{rule.trigger_type}#{trigger_summary.present? ? " (#{trigger_summary})" : ''} | action: #{rule.action_type}#{action_summary.present? ? " (#{action_summary})" : ''}"
      end.join("\n")
    end

    def events_block(events)
      return nil if events.empty?

      events.map do |event|
        "- #{event.title} | #{event.start_time&.strftime('%Y-%m-%d %H:%M') || 'unknown'} -> #{event.end_time&.strftime('%Y-%m-%d %H:%M') || 'none'} | #{event.location.presence || 'n/a'}"
      end.join("\n")
    end

    def reminders_block(reminders)
      return nil if reminders.empty?

      reminders.map do |reminder|
        "- #{reminder.title} | at: #{reminder.trigger_at&.strftime('%Y-%m-%d %H:%M') || 'unknown'} | #{reminder.channel} | #{reminder.status}"
      end.join("\n")
    end

    def tasks_block(tasks)
      return nil if tasks.empty?

      tasks.map do |task|
        "- #{task.title} | #{task.assignee&.name.presence || 'unassigned'} | #{task.status} | p#{task.priority} | due: #{task.due_at&.strftime('%Y-%m-%d %H:%M') || 'none'}"
      end.join("\n")
    end

    def truncate_text(text, limit)
      value = text.to_s
      return value if value.length <= limit

      "#{value.first(limit)}..."
    end

    def prompt_payload
      @prompt_payload ||= begin
        sections = build_sections
        prompt = [
          %(You are the Family AI Brain for "#{@family.name}".),
          "Reply in Ukrainian unless the user clearly writes in another language.",
          "Be concise, practical, and action-oriented.",
          "Use only the provided family context. If data is missing, say so.",
          "Prefer checklists, next steps, reminders, or a short clarifying question.",
          "",
          sections.map { |section| "#{section[:title]}\n#{section[:content]}" }
        ].flatten.join("\n\n").strip

        {
          prompt: prompt,
          metrics: {
            prompt_version: PROMPT_VERSION,
            system_prompt_chars: prompt.length,
            system_prompt_tokens: FamilyBrain::TokenEstimator.estimate(prompt),
            sections: sections.to_h do |section|
              [
                section[:key],
                {
                  title: section[:title],
                  items_count: section[:items_count],
                  chars: section[:content].length,
                  tokens_estimate: FamilyBrain::TokenEstimator.estimate(section[:content])
                }
              ]
            end
          }
        }
      end
    end

    def build_sections
      relevant_life_logs = retrieval_service.relevant_life_logs
      relevant_knowledge = retrieval_service.relevant_knowledge
      relevant_documents = retrieval_service.relevant_documents
      upcoming_events = @family.events.upcoming_or_ongoing.limit(EVENT_LIMIT).to_a
      active_reminders = @family.reminders.upcoming_first.limit(REMINDER_LIMIT).to_a
      active_rules = @family.automation_rules.active_first.limit(AUTOMATION_LIMIT).to_a
      open_tasks = @family.tasks.open_first.limit(TASK_LIMIT).to_a

      [
        section(:account, "ACCOUNT", account_context_block, 1),
        section(:family_members, "FAMILY MEMBERS", family_members_block, @family.family_members.size),
        section(:life_logs, "LIFE LOGS", life_logs_block(relevant_life_logs), relevant_life_logs.size),
        section(:family_knowledge, "FAMILY KNOWLEDGE", family_knowledge_block(relevant_knowledge), relevant_knowledge.size),
        section(:documents, "DOCUMENTS", documents_block(relevant_documents), relevant_documents.size),
        section(:events, "UPCOMING EVENTS", events_block(upcoming_events), upcoming_events.size),
        section(:reminders, "ACTIVE REMINDERS", reminders_block(active_reminders), active_reminders.size),
        section(:automation_rules, "AUTOMATION RULES", automation_rules_block(active_rules), active_rules.size),
        section(:tasks, "OPEN TASKS", tasks_block(open_tasks), open_tasks.size),
        section(:rules, "RULES", rules_block, 5)
      ].compact
    end

    def section(key, title, content, items_count)
      return nil if content.blank?

      { key: key, title: title, content: content, items_count: items_count }
    end

    def rules_block
      <<~TEXT.strip
        - Do not invent facts, dates, or commitments.
        - Treat events, reminders, tasks, and knowledge as the source of truth.
        - If the request is ambiguous, ask one short clarifying question.
        - Keep answers compact unless the user asks for more detail.
        - When useful, suggest the next concrete action for the family.
      TEXT
    end

    def retrieval_service
      @retrieval_service ||= FamilyBrain::RetrievalService.new(family: @family, query: @current_message.content)
    end

    def summarize_json(value)
      value.to_h.first(2).map { |key, item| "#{key}: #{item}" }.join(", ")
    end
  end
end
