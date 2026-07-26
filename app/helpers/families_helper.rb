module FamiliesHelper
  FAMILY_TAB_DEFINITIONS = [
    { key: "chat", label: "Чат", icon: "message" },
    { key: "calendar", label: "Календар", icon: "calendar", count: false },
    { key: "tasks", label: "Задачі", icon: "check" },
    { key: "events", label: "Події", icon: "calendar" },
    { key: "reminders", label: "Нагадування", icon: "bell" },
    { key: "documents", label: "Документи", icon: "document" },
    { key: "knowledge", label: "Знання", icon: "brain" },
    { key: "logs", label: "Історія", icon: "clock" },
    { key: "ai_logs", label: "AI журнал", icon: "terminal", debug_only: true, count: false },
    { key: "members", label: "Люди", icon: "users" },
    { key: "connections", label: "Зв’язки", icon: "link" },
    { key: "automations", label: "Автоматизації", icon: "bolt" }
  ].freeze

  def family_tab_definitions
    FAMILY_TAB_DEFINITIONS.reject { |tab| tab[:debug_only] && !ai_debug_ui_enabled? }
  end

  def family_tab_href(family, tab_key)
    tab_key == "chat" ? family_path(family) : tab_family_path(family, tab: tab_key)
  end

  def family_tab_count(family, tab_key)
    case tab_key
    when "chat"
      family.conversations.find_by(started_on: family.local_date)&.messages_count.to_i
    when "tasks" then family.tasks.active.count
    when "events" then family.events.upcoming_or_ongoing.count
    when "reminders" then family.reminders.active.count
    when "documents" then family.documents.count
    when "knowledge" then family.family_knowledge.count
    when "logs" then family.life_logs.count
    when "ai_logs" then family.ai_interactions.tracked_llm_requests.count
    when "members" then family.family_members.count
    when "connections" then family.calendar_connections.where(active: true).count
    when "automations" then family.automation_rules.where(active: true).count
    else 0
    end
  end

  def family_tab_count_dom_id(family, tab_key)
    "#{dom_id(family)}_tab_count_#{tab_key}"
  end

  def family_calendar_entries(family)
    zone = ActiveSupport::TimeZone[family.timezone.presence] || Time.zone
    entries = Hash.new { |hash, date| hash[date] = [] }

    @calendar_events.each do |event|
      start_date = event.start_time.in_time_zone(zone).to_date
      finish_at = event.display_end_time || event.start_time
      finish_date = finish_at.in_time_zone(zone).to_date
      (start_date..finish_date).each do |date|
        next unless date.between?(@calendar_grid_start, @calendar_grid_end)

        entries[date] << { type: "event", title: event.title, time: event.all_day? ? nil : event.start_time.in_time_zone(zone), record: event,
          continues_before: date > start_date, continues_after: date < finish_date }
      end
    end

    [ [ @calendar_tasks, "task", :due_at ], [ @calendar_reminders, "reminder", :trigger_at ], [ @calendar_life_logs, "log", :happened_at ] ].each do |records, type, attribute|
      records.each do |record|
        time = record.public_send(attribute).in_time_zone(zone)
        entries[time.to_date] << { type:, title: type == "log" ? record.summary : record.title, time:, record: }
      end
    end

    entries.each_value { |items| items.sort_by! { |item| [ item[:time].nil? ? 0 : 1, item[:time] || Time.at(0), item[:title].to_s ] } }
    entries
  end

  def family_calendar_entry_href(family, entry)
    tab = { "event" => "events", "task" => "tasks", "reminder" => "reminders", "log" => "logs" }.fetch(entry[:type])
    "#{family_tab_href(family, tab)}##{dom_id(entry[:record])}"
  end

  def conversation_display_title(conversation, family)
    today = family.local_date
    return "Сьогодні · #{conversation.title}" if conversation.started_on == today
    return "Вчора · #{conversation.title}" if conversation.started_on == today - 1.day

    conversation.title
  end

  def conversation_message_count_dom_id(conversation)
    "conversation_#{conversation.started_on.iso8601}_message_count"
  end

  def automation_execution_filter_options
    [
      [ "Усі", "all" ],
      [ "Chat-triggered", "chat" ],
      [ "Duplicates", "duplicates" ]
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
    sections = (interaction.llm_metadata || {}).fetch("sections", {})
    entries = sections.sort_by { |_, data| -data.fetch("tokens_estimate", 0).to_i }.first(limit)
    return "no section data" if entries.empty?

    entries.map do |key, data|
      "#{key.to_s.humanize}: ~#{data.fetch('tokens_estimate', 0)}t"
    end.join(" | ")
  end

  def ai_log_filter_href(family, log_type, page: nil)
    tab_family_path(family, tab: "ai_logs", log_type:, page:)
  end

  private

  def dom_id_for_type(type, id)
    "#{type}_#{id}"
  end
end
