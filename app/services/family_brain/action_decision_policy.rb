module FamilyBrain
  class ActionDecisionPolicy
    Decision = Data.define(:state, :intent_strength, :risk, :missing_fields)

    REQUIRED_FIELDS = {
      "create_task" => %w[title],
      "update_task" => %w[record_id changed_fields],
      "create_reminder" => %w[title trigger_at],
      "update_reminder" => %w[record_id changed_fields],
      "create_event" => %w[title start_at],
      "update_event" => %w[record_id changed_fields],
      "create_knowledge" => %w[key value],
      "update_knowledge" => %w[record_id changed_fields],
      "create_life_log" => %w[event_type summary happened_at],
      "update_life_log" => %w[record_id changed_fields],
      "create_document" => %w[title content],
      "update_document" => %w[record_id changed_fields],
      "create_automation_rule" => %w[title automation_trigger_type automation_action_type],
      "update_automation_rule" => %w[record_id changed_fields]
    }.freeze

    RISK_BY_ACTION = {
      "create_task" => "low",
      "create_reminder" => "low",
      "create_event" => "low",
      "update_task" => "medium",
      "update_reminder" => "medium",
      "update_event" => "medium",
      "create_knowledge" => "low",
      "update_knowledge" => "high",
      "create_life_log" => "low",
      "update_life_log" => "medium",
      "create_document" => "high",
      "update_document" => "high",
      "create_automation_rule" => "high",
      "update_automation_rule" => "high"
    }.freeze

    def call(action)
      action = action.to_h.deep_stringify_keys
      intent_strength = normalize_intent_strength(action["intent_strength"])
      risk = RISK_BY_ACTION.fetch(action["kind"], "high")
      missing_fields = required_fields(action).select { |field| field_missing?(action, field) }
      missing_fields.concat(Array(action["ambiguities"]).filter_map { |value| value.to_s.strip.presence })
      missing_fields.uniq!

      state = if missing_fields.any?
        "awaiting_clarification"
      elsif intent_strength == "inferred" || risk == "high"
        "awaiting_confirmation"
      else
        "ready"
      end

      Decision.new(
        state: state,
        intent_strength: intent_strength,
        risk: risk,
        missing_fields: missing_fields
      )
    end

    private

    def required_fields(action)
      fields = REQUIRED_FIELDS.fetch(action["kind"], []).dup
      fields << "evidence" if REQUIRED_FIELDS.key?(action["kind"])
      return fields unless action["kind"] == "create_automation_rule"

      fields.concat(trigger_required_fields(action["automation_trigger_type"]))
      fields.concat(automation_action_required_fields(action["automation_action_type"]))
      fields
    end

    def field_missing?(action, field)
      value = action[field]
      return value.to_i <= 0 if field == "record_id"
      return value.to_i <= 0 if field == "automation_trigger_day"
      return Array(value).empty? if field.in?(%w[changed_fields evidence])

      value.blank?
    end

    def normalize_intent_strength(value)
      value.to_s == "explicit" ? "explicit" : "inferred"
    end

    def trigger_required_fields(trigger_type)
      case trigger_type
      when "schedule_daily" then %w[automation_trigger_time]
      when "schedule_weekly" then %w[automation_trigger_weekday automation_trigger_time]
      when "schedule_monthly" then %w[automation_trigger_day automation_trigger_time]
      when "chat_keyword" then %w[automation_trigger_keyword automation_match_mode]
      else []
      end
    end

    def automation_action_required_fields(action_type)
      case action_type
      when "create_ai_note", "create_life_log" then %w[automation_action_content]
      when "create_family_knowledge" then %w[key value]
      when "create_task", "create_event", "create_reminder" then %w[automation_action_title]
      else []
      end
    end
  end
end
