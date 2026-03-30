module FamiliesHelper
  FAMILY_TAB_DEFINITIONS = [
    { key: "chat", label: "Чат", kicker: "AI" },
    { key: "tasks", label: "Задачі", kicker: "Execution" },
    { key: "events", label: "Події", kicker: "Calendar" },
    { key: "reminders", label: "Нагадування", kicker: "Notification" },
    { key: "documents", label: "Документи", kicker: "RAG" },
    { key: "knowledge", label: "Knowledge", kicker: "Semantic" },
    { key: "logs", label: "Life logs", kicker: "Episodic" },
    { key: "members", label: "Члени сім'ї", kicker: "Context" },
    { key: "connections", label: "Календарі", kicker: "Sync" },
    { key: "automations", label: "Automations", kicker: "Procedural" }
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
end
