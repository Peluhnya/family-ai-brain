module FamiliesHelper
  FAMILY_TAB_DEFINITIONS = [
    { key: "chat", label: "Чат", icon: "message" },
    { key: "tasks", label: "Задачі", icon: "check" },
    { key: "events", label: "Події", icon: "calendar" },
    { key: "reminders", label: "Нагадування", icon: "bell" },
    { key: "documents", label: "Документи", icon: "document" },
    { key: "knowledge", label: "Знання", icon: "brain" },
    { key: "logs", label: "Історія", icon: "clock" },
    { key: "members", label: "Люди", icon: "users" },
    { key: "connections", label: "Зв’язки", icon: "link" },
    { key: "automations", label: "Автоматизації", icon: "bolt" }
  ].freeze

  def family_tab_definitions
    FAMILY_TAB_DEFINITIONS
  end

  def family_tab_href(family, tab_key)
    tab_key == "chat" ? family_path(family) : tab_family_path(family, tab: tab_key)
  end

  def family_tab_count(family, tab_key)
    case tab_key
    when "chat" then family.ai_interactions.count
    when "tasks" then family.tasks.active.count
    when "events" then family.events.where("start_time >= ?", Time.current.beginning_of_day).count
    when "reminders" then family.reminders.active.count
    when "documents" then family.documents.count
    when "knowledge" then family.family_knowledge.count
    when "logs" then family.life_logs.count
    when "members" then family.family_members.count
    when "connections" then family.calendar_connections.where(active: true).count
    when "automations" then family.automation_rules.where(active: true).count
    else 0
    end
  end

  def family_tab_count_dom_id(family, tab_key)
    "#{dom_id(family)}_tab_count_#{tab_key}"
  end

  def automation_execution_filter_options
    [
      ["Усі", "all"],
      ["Chat-triggered", "chat"],
      ["Duplicates", "duplicates"]
    ]
  end

  def automation_execution_filter_href(family, filter)
    tab_family_path(family, tab: "automations", execution_filter: filter)
  end

  def automation_execution_for(record)
    return nil unless defined?(@automation_execution_map)

    @automation_execution_map[record.id]
  end

  def automation_execution_source_message(execution)
    return nil if execution.blank?
    return nil unless execution.source_type == "AiInteraction"
    return nil unless defined?(@automation_execution_source_map)

    @automation_execution_source_map[execution.source_id]
  end

  def automation_execution_entity_href(execution)
    return nil if execution.created_entity_type.blank? || execution.created_entity_id.blank?

    case execution.created_entity_type
    when "Task"
      "#{family_tab_href(execution.family, 'tasks')}##{dom_id_for_type('task', execution.created_entity_id)}"
    when "Event"
      "#{family_tab_href(execution.family, 'events')}##{dom_id_for_type('event', execution.created_entity_id)}"
    when "Reminder"
      "#{family_tab_href(execution.family, 'reminders')}##{dom_id_for_type('reminder', execution.created_entity_id)}"
    else
      nil
    end
  end

  def automation_execution_source_href(execution)
    source_message = automation_execution_source_message(execution)
    return nil if source_message.blank?

    "#{family_tab_href(execution.family, 'chat')}##{dom_id(source_message)}"
  end

  def family_ai_usage_section_summary(interaction, limit: 2)
    entries = interaction.section_usage.sort_by { |_, data| -data.fetch("tokens_estimate", 0).to_i }.first(limit)
    return "no section data" if entries.empty?

    entries.map do |key, data|
      "#{key.to_s.humanize}: ~#{data.fetch('tokens_estimate', 0)}t"
    end.join(" | ")
  end

  private

  def dom_id_for_type(type, id)
    "#{type}_#{id}"
  end
end
