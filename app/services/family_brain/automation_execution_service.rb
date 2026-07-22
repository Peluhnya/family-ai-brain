module FamilyBrain
  class AutomationExecutionService
    def initialize(rule:, context: {})
      @rule = rule
      @family = rule.family
      @context = context
    end

    def call
      ActiveRecord::Base.transaction do
        execution = acquire_execution_guard!
        entity = execute_action!
        finalize_execution!(execution, entity)
        @rule.update!(last_executed_at: Time.current)
      end
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    private

    def execute_action!
      case @rule.action_type
      when "create_ai_note"
        @family.ai_interactions.create!(
          role: "assistant",
          content: interpolate(@rule.action_config["content"]),
          model: "automation-rule"
        )
      when "create_life_log"
        log = @family.life_logs.new(
          event_type: @rule.action_config["event_type"].presence || "automation",
          summary: interpolate(@rule.action_config["summary"]),
          raw_text: interpolate(@rule.action_config["raw_text"]),
          importance: (@rule.action_config["importance"] || 0.7).to_f,
          happened_at: Time.current
        )
        log.embedding = FamilyBrain::EmbeddingService.embed([log.event_type, log.summary, log.raw_text].compact.join("\n"), account: @family.account)
        log.save!
        FamilyBrain::KnowledgeSyncService.new(family: @family, text: [log.summary, log.raw_text].compact.join("\n"), source: "automation_rule:auto").call
        log
      when "create_family_knowledge"
        key = interpolate(@rule.action_config["key"])
        value = interpolate(@rule.action_config["value"])
        knowledge = @family.family_knowledge.find_or_initialize_by(key: key)
        knowledge.value = value
        knowledge.source = @rule.action_config["source"].presence || "automation_rule"
        knowledge.confidence = (@rule.action_config["confidence"] || 0.8).to_f.clamp(0.0, 1.0)
        knowledge.embedding = FamilyBrain::EmbeddingService.embed("#{key}: #{value}", account: @family.account)
        knowledge.save!
        knowledge
      when "create_task"
        @family.tasks.create!(
          title: interpolate(@rule.action_config["title"]),
          description: interpolate(@rule.action_config["description"]),
          assigned_to: resolved_assignee_id,
          due_at: resolve_due_at,
          status: normalize_task_status(@rule.action_config["status"]),
          priority: normalize_task_priority(@rule.action_config["priority"])
        )
      when "create_event"
        start_time = resolve_event_start_time
        @family.events.create!(
          title: interpolate(@rule.action_config["title"]),
          location: interpolate(@rule.action_config["location"]),
          source: @rule.action_config["source"].presence || "automation_rule",
          start_time: start_time,
          end_time: start_time + normalize_event_duration(@rule.action_config["duration_hours"]).hours
        )
      when "create_reminder"
        @family.reminders.create!(
          title: interpolate(@rule.action_config["title"]),
          trigger_at: resolve_reminder_trigger_at,
          channel: normalize_reminder_channel(@rule.action_config["channel"]),
          status: "pending"
        )
      else
        raise "Unsupported automation action: #{@rule.action_type}"
      end
    end

    def acquire_execution_guard!
      return nil if source_type.blank? || source_id.blank?

      @rule.automation_rule_executions.create!(
        family: @family,
        action_type: @rule.action_type,
        source_type: source_type,
        source_id: source_id,
        status: "completed",
        context_digest: context_digest
      )
    end

    def finalize_execution!(execution, entity)
      return if execution.blank?

      execution.update!(
        created_entity_type: entity.class.name,
        created_entity_id: entity.id
      )
    end

    def source_type
      @context[:source_type].to_s.presence
    end

    def source_id
      @context[:source_id].presence
    end

    def context_digest
      Digest::SHA256.hexdigest([
        @rule.id,
        @rule.action_type,
        @context[:keyword].to_s,
        @context[:message].to_s
      ].join(":"))
    end

    def interpolate(value)
      value.to_s
        .gsub("{{family_name}}", @family.name.to_s)
        .gsub("{{keyword}}", @context[:keyword].to_s)
        .gsub("{{message}}", @context[:message].to_s)
    end

    def resolve_due_at
      due_in_days = @rule.action_config["due_in_days"].to_i
      return if due_in_days <= 0

      due_in_days.days.from_now
    end

    def resolved_assignee_id
      assignee_id = @rule.action_config["assigned_to"].presence
      return if assignee_id.blank?

      @family.family_members.exists?(id: assignee_id) ? assignee_id : nil
    end

    def normalize_task_status(status)
      status = status.to_s
      Task::STATUSES.include?(status) ? status : "pending"
    end

    def normalize_task_priority(priority)
      priority.to_i.clamp(1, 5)
    end

    def resolve_event_start_time
      days = @rule.action_config["start_in_days"].to_i
      days = 0 if days.negative?
      (days.days.from_now).change(min: 0)
    end

    def normalize_event_duration(duration_hours)
      hours = duration_hours.to_i
      return 1 if hours <= 0

      hours.clamp(1, 24)
    end

    def resolve_reminder_trigger_at
      days = @rule.action_config["trigger_in_days"].to_i
      days = 0 if days.negative?
      (days.days.from_now).change(min: 0)
    end

    def normalize_reminder_channel(channel)
      channel = channel.to_s
      Reminder::CHANNELS.include?(channel) ? channel : "app"
    end
  end
end
