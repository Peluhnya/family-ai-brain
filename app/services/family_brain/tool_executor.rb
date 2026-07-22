require "digest"

module FamilyBrain
  class ToolExecutor
    Result = Data.define(:kind, :status, :entity_type, :entity_id, :title, :message) do
      def successful?
        %w[created updated].include?(status)
      end

      def to_h
        {
          kind: kind,
          status: status,
          entity_type: entity_type,
          entity_id: entity_id,
          title: title,
          message: message
        }
      end
    end

    def initialize(family:, user_message:, source_user_text:, now: Time.current, locale: nil)
      @family = family
      @user_message = user_message
      @source_user_text = source_user_text.to_s
      @zone = ActiveSupport::TimeZone[family.timezone.presence] || Time.zone
      @now = now.in_time_zone(@zone)
      @locale = FamilyBrain::LocaleCatalog.normalize(locale) ||
        FamilyBrain::LanguageResolver.for_message(
          family: family,
          message: @user_message,
          context: @source_user_text
        )
      @date_parser = FamilyBrain::TemporalParser.new(
        reference_time: @now,
        timezone: @zone.tzinfo.name,
        locale: @locale
      )
    end

    def call(actions)
      Array(actions).map { |action| execute(action.deep_stringify_keys) }
    end

    private

    def execute(action)
      fingerprint = action_fingerprint(action)
      effect = find_or_initialize_effect(action, fingerprint)
      return result_from_existing_effect(effect, action) if effect.persisted? && %w[completed skipped].include?(effect.status)

      validate_evidence!(action)
      entity, status, message = dispatch(action)
      persist_effect!(effect, entity:, status: status == "skipped" ? "skipped" : "completed", message: message)

      build_result(action, entity:, status:, message:)
    rescue StandardError => error
      persist_failed_effect(effect, action, fingerprint, error)
      Rails.logger.error(
        "family_brain_tool_failed family_id=#{@family.id} interaction_id=#{@user_message.id} " \
        "action=#{action['kind']} error=#{error.class}: #{error.message}"
      )
      Result.new(
        kind: action["kind"],
        status: "failed",
        entity_type: nil,
        entity_id: nil,
        title: action["title"].to_s,
        message: error.message
      )
    end

    def dispatch(action)
      case action.fetch("kind")
      when "create_task" then create_task(action)
      when "update_task" then update_task(action)
      when "create_reminder" then create_reminder(action)
      when "update_reminder" then update_reminder(action)
      when "create_event" then create_event(action)
      when "update_event" then update_event(action)
      when "create_knowledge" then create_knowledge(action)
      when "update_knowledge" then update_knowledge(action)
      when "create_life_log" then create_life_log(action)
      when "update_life_log" then update_life_log(action)
      when "create_document" then create_document(action)
      when "update_document" then update_document(action)
      when "create_automation_rule" then create_automation_rule(action)
      when "update_automation_rule" then update_automation_rule(action)
      else raise ArgumentError, "Unsupported action #{action['kind']}"
      end
    end

    def create_task(action)
      validate_title!(action)
      due_at = parse_time(action["due_at"], fallback_text: evidence_text(action), default_hour: 18, honor_fallback_clock: false)
      existing = find_matching_task(action["title"])
      return [ existing, "skipped", action_message(:task_exists) ] if existing

      task = @family.tasks.create!(
        title: action["title"].strip,
        description: action["description"].to_s.strip.presence,
        assigned_to: resolve_assignee_id(action["assignee_name"]),
        due_at: due_at,
        status: "pending",
        priority: action["priority"].to_i.clamp(1, 5)
      )
      [ task, "created", action_message(:task_created) ]
    end

    def update_task(action)
      task = @family.tasks.find(action["record_id"])
      attributes = {}
      attributes[:title] = action["title"].strip if changed?(action, "title") && action["title"].present?
      attributes[:description] = action["description"].strip if changed?(action, "description")
      attributes[:assigned_to] = resolve_assignee_id(action["assignee_name"]) if changed?(action, "assignee_name")
      attributes[:priority] = action["priority"].to_i.clamp(1, 5) if changed?(action, "priority")
      attributes[:status] = normalized_task_status(action["status"]) if changed?(action, "status")
      attributes[:due_at] = parse_time(action["due_at"], fallback_text: evidence_text(action), default_hour: 18, honor_fallback_clock: false) if changed?(action, "due_at")
      return [ task, "skipped", action_message(:task_unchanged) ] if attributes.empty?

      task.update!(attributes)
      [ task, "updated", action_message(:task_updated) ]
    end

    def create_reminder(action)
      validate_title!(action)
      trigger_at = parse_time(action["trigger_at"], fallback_text: evidence_text(action), default_hour: 9)
      raise ArgumentError, error_message(:reminder_time_missing) unless trigger_at

      existing = find_matching_reminder(action["title"], trigger_at)
      return [ existing, "skipped", action_message(:reminder_exists) ] if existing

      reminder = @family.reminders.create!(
        title: action["title"].strip,
        trigger_at: trigger_at,
        channel: normalize_channel(action["channel"]),
        status: "pending"
      )
      [ reminder, "created", action_message(:reminder_created) ]
    end

    def update_reminder(action)
      reminder = @family.reminders.find(action["record_id"])
      attributes = {}
      attributes[:title] = action["title"].strip if changed?(action, "title") && action["title"].present?
      attributes[:trigger_at] = parse_time(action["trigger_at"], fallback_text: evidence_text(action), default_hour: 9) if changed?(action, "trigger_at")
      attributes[:channel] = normalize_channel(action["channel"]) if changed?(action, "channel")
      attributes[:status] = normalized_reminder_status(action["status"]) if changed?(action, "status")
      return [ reminder, "skipped", action_message(:reminder_unchanged) ] if attributes.compact.empty?

      reminder.update!(attributes.compact)
      [ reminder, "updated", action_message(:reminder_updated) ]
    end

    def create_event(action)
      validate_title!(action)
      start_at, end_at = event_times(action)
      raise ArgumentError, error_message(:event_start_missing) unless start_at

      existing = find_matching_event(action["title"], start_at)
      return [ existing, "skipped", action_message(:event_exists) ] if existing

      event = @family.events.create!(
        title: action["title"].strip,
        location: action["location"].to_s.strip.presence,
        source: "ai_chat",
        start_time: start_at,
        end_time: end_at,
        all_day: action["all_day"]
      )
      [ event, "created", action_message(:event_created) ]
    end

    def update_event(action)
      event = @family.events.find(action["record_id"])
      attributes = {}
      attributes[:title] = action["title"].strip if changed?(action, "title") && action["title"].present?
      attributes[:location] = action["location"].strip if changed?(action, "location")
      if changed?(action, "start_at") || changed?(action, "end_at") || changed?(action, "all_day")
        start_at, end_at = event_times(action, existing_event: event)
        attributes[:start_time] = start_at if start_at
        attributes[:end_time] = end_at if end_at
        attributes[:all_day] = action["all_day"] if changed?(action, "all_day")
      end
      return [ event, "skipped", action_message(:event_unchanged) ] if attributes.empty?

      event.update!(attributes)
      [ event, "updated", action_message(:event_updated) ]
    end

    def create_knowledge(action)
      key, value = validated_knowledge(action)
      existing = @family.family_knowledge.find_by(key: key)
      if existing
        return [ existing, "skipped", action_message(:knowledge_exists) ] if normalized_same?(existing.value, value)

        raise ArgumentError, error_message(:knowledge_conflict)
      end

      knowledge = @family.family_knowledge.create!(
        key: key,
        value: value,
        source: action["source"].to_s.presence || "chat:planner",
        confidence: action["confidence"].to_f.clamp(0.0, 1.0),
        embedding: FamilyBrain::EmbeddingService.embed("#{key}: #{value}", account: @family.account)
      )
      [ knowledge, "created", action_message(:knowledge_created) ]
    end

    def update_knowledge(action)
      knowledge = @family.family_knowledge.find(action["record_id"])
      attributes = {}
      attributes[:key] = validated_knowledge_key(action["key"]) if changed?(action, "key")
      if changed?(action, "value")
        value = validated_evidence_value(action["value"])
        attributes[:value] = value
      end
      attributes[:source] = action["source"].to_s.presence || "chat:planner" if changed?(action, "source")
      attributes[:confidence] = action["confidence"].to_f.clamp(0.0, 1.0) if changed?(action, "confidence")
      return [ knowledge, "skipped", action_message(:knowledge_unchanged) ] if attributes.empty?

      merged_key = attributes.fetch(:key, knowledge.key)
      merged_value = attributes.fetch(:value, knowledge.value)
      attributes[:embedding] = FamilyBrain::EmbeddingService.embed("#{merged_key}: #{merged_value}", account: @family.account)
      knowledge.update!(attributes)
      [ knowledge, "updated", action_message(:knowledge_updated) ]
    end

    def create_life_log(action)
      summary = validated_evidence_value(action["summary"])
      happened_at = parse_time(action["happened_at"], fallback_text: evidence_text(action), default_hour: @now.hour)
      raise ArgumentError, error_message(:life_log_time_missing) unless happened_at
      raise ArgumentError, error_message(:life_log_time_future) if happened_at > @now + 5.minutes

      existing = matching_life_log(summary, happened_at)
      return [ existing, "skipped", action_message(:life_log_exists) ] if existing

      event_type = normalized_life_log_type(action["event_type"])
      life_log = @family.life_logs.create!(
        event_type: event_type,
        summary: summary,
        raw_text: validated_optional_evidence_value(action["raw_text"]) || summary,
        importance: action["importance"].to_f.clamp(0.0, 1.0),
        happened_at: happened_at,
        embedding: FamilyBrain::EmbeddingService.embed([ event_type, summary ].join("\n"), account: @family.account)
      )
      [ life_log, "created", action_message(:life_log_created) ]
    end

    def update_life_log(action)
      life_log = @family.life_logs.find(action["record_id"])
      attributes = {}
      attributes[:event_type] = normalized_life_log_type(action["event_type"]) if changed?(action, "event_type")
      attributes[:summary] = validated_evidence_value(action["summary"]) if changed?(action, "summary")
      attributes[:raw_text] = validated_optional_evidence_value(action["raw_text"]) if changed?(action, "raw_text")
      attributes[:importance] = action["importance"].to_f.clamp(0.0, 1.0) if changed?(action, "importance")
      if changed?(action, "happened_at")
        happened_at = parse_time(action["happened_at"], fallback_text: evidence_text(action), default_hour: @now.hour)
        raise ArgumentError, error_message(:life_log_time_future) if happened_at && happened_at > @now + 5.minutes
        attributes[:happened_at] = happened_at
      end
      return [ life_log, "skipped", action_message(:life_log_unchanged) ] if attributes.compact.empty?

      merged_type = attributes.fetch(:event_type, life_log.event_type)
      merged_summary = attributes.fetch(:summary, life_log.summary)
      attributes[:embedding] = FamilyBrain::EmbeddingService.embed([ merged_type, merged_summary ].join("\n"), account: @family.account)
      life_log.update!(attributes.compact)
      [ life_log, "updated", action_message(:life_log_updated) ]
    end

    def create_document(action)
      validate_title!(action)
      content = validated_document_content(action["content"])
      existing = matching_document(action["title"], content)
      return [ existing, "skipped", action_message(:document_exists) ] if existing

      document = @family.documents.create!(
        title: action["title"].strip,
        content: content,
        embedding: FamilyBrain::EmbeddingService.embed(
          [ action["title"], content ].join("\n\n"),
          account: @family.account
        )
      )
      [ document, "created", action_message(:document_created) ]
    end

    def update_document(action)
      document = @family.documents.find(action["record_id"])
      attributes = {}
      if changed?(action, "title")
        validate_title!(action)
        attributes[:title] = action["title"].strip
      end
      attributes[:content] = validated_document_content(action["content"]) if changed?(action, "content")
      return [ document, "skipped", action_message(:document_unchanged) ] if attributes.empty?

      merged_title = attributes.fetch(:title, document.title)
      merged_content = attributes.fetch(:content, document.content)
      attributes[:embedding] = FamilyBrain::EmbeddingService.embed(
        [ merged_title, merged_content ].join("\n\n"),
        account: @family.account
      )
      document.update!(attributes)
      [ document, "updated", action_message(:document_updated) ]
    end

    def create_automation_rule(action)
      validate_title!(action)
      trigger_type, trigger_config = automation_trigger(action)
      action_type, action_config = automation_action(action)
      existing = matching_automation_rule(action["title"], trigger_type, trigger_config, action_type, action_config)
      return [ existing, "skipped", action_message(:automation_exists) ] if existing

      rule = @family.automation_rules.create!(
        name: action["title"].strip,
        active: action["active"] == true,
        template_key: "ai_chat_custom",
        trigger_type: trigger_type,
        trigger_config: trigger_config,
        action_type: action_type,
        action_config: action_config
      )
      [ rule, "created", action_message(:automation_created) ]
    end

    def update_automation_rule(action)
      rule = @family.automation_rules.find(action["record_id"])
      attributes = {}
      if changed?(action, "title")
        validate_title!(action)
        attributes[:name] = action["title"].strip
      end
      attributes[:active] = action["active"] == true if changed?(action, "active")
      if Array(action["changed_fields"]).any? { |field| field.start_with?("automation_trigger_") || field == "automation_match_mode" }
        trigger_type, trigger_config = automation_trigger(action)
        attributes[:trigger_type] = trigger_type
        attributes[:trigger_config] = trigger_config
      end
      if Array(action["changed_fields"]).any? { |field| field.start_with?("automation_action_") || field.in?(%w[key value confidence event_type importance]) }
        action_type, action_config = automation_action(action)
        attributes[:action_type] = action_type
        attributes[:action_config] = action_config
      end
      return [ rule, "skipped", action_message(:automation_unchanged) ] if attributes.empty?

      rule.update!(attributes)
      [ rule, "updated", action_message(:automation_updated) ]
    end

    def event_times(action, existing_event: nil)
      all_day = existing_event && !changed?(action, "all_day") ? existing_event.all_day? : action["all_day"]
      start_at = existing_event&.start_time unless changed?(action, "start_at")
      end_at = existing_event&.end_time unless changed?(action, "end_at")
      start_at ||= parse_time(action["start_at"], fallback_text: changed?(action, "start_at") ? evidence_text(action) : nil, default_hour: all_day ? 0 : 9)
      end_at ||= parse_time(action["end_at"], fallback_text: changed?(action, "end_at") ? evidence_text(action) : nil, default_hour: all_day ? 0 : 10)

      if start_at.nil? && existing_event.nil?
        range = @date_parser.parse_range(evidence_text(action))
        start_at, parsed_end_at = range if range
        end_at ||= parsed_end_at
      end

      return [ nil, nil ] unless start_at

      start_at = start_at.in_time_zone(@zone).beginning_of_day if all_day
      end_at ||= all_day ? start_at + 1.day : start_at + 1.hour
      end_at = end_at.in_time_zone(@zone).beginning_of_day if all_day
      end_at += 1.day if all_day && end_at <= start_at
      raise ArgumentError, error_message(:event_end_invalid) if end_at <= start_at

      [ start_at, end_at ]
    end

    def parse_time(value, fallback_text:, default_hour:, honor_fallback_clock: true)
      parsed = @date_parser.parse_datetime(value, default_hour: default_hour) if value.present?
      parsed || (@date_parser.parse_datetime(fallback_text, default_hour: default_hour, honor_clock: honor_fallback_clock) if fallback_text.present?)
    end

    def validate_title!(action)
      title = action["title"].to_s.strip
      raise ArgumentError, error_message(:title_blank) unless FamilyBrain::GroundedExtraction.meaningful_title?(title)

      grounded_title = FamilyBrain::GroundedExtraction.grounded_title(title, evidence_text(action))
      raise ArgumentError, error_message(:title_unverified) unless grounded_title

      action["title"] = grounded_title
    end

    def validate_evidence!(action)
      quotes = Array(action["evidence"]).map(&:to_s).reject(&:blank?)
      raise ArgumentError, error_message(:evidence_missing) if quotes.empty?
      unless quotes.any? { |quote| FamilyBrain::GroundedExtraction.evidence_present?(@source_user_text, quote) }
        raise ArgumentError, error_message(:evidence_unverified)
      end

      missing_quote = quotes.find do |quote|
        !FamilyBrain::GroundedExtraction.evidence_fragment_present?(@source_user_text, quote)
      end
      raise ArgumentError, error_message(:evidence_unverified) if missing_quote
    end

    def validated_knowledge(action)
      [ validated_knowledge_key(action["key"]), validated_evidence_value(action["value"]) ]
    end

    def validated_knowledge_key(value)
      key = value.to_s.strip
      raise ArgumentError, error_message(:knowledge_key_invalid) unless key.match?(/\A[a-z0-9]+(?:_[a-z0-9]+)*\z/)

      key
    end

    def validated_evidence_value(value)
      value = value.to_s.strip
      unless FamilyBrain::GroundedExtraction.meaningful_phrase?(value) &&
          FamilyBrain::GroundedExtraction.evidence_present?(@source_user_text, value)
        raise ArgumentError, error_message(:memory_value_unverified)
      end

      value
    end

    def validated_optional_evidence_value(value)
      return if value.blank?

      validated_evidence_value(value)
    end

    def normalized_life_log_type(value)
      allowed = %w[family_moment trip celebration achievement health milestone other]
      allowed.include?(value.to_s) ? value.to_s : "other"
    end

    def matching_life_log(summary, happened_at)
      normalized = FamilyBrain::GroundedExtraction.normalize_text(summary)
      @family.life_logs.where(happened_at: (happened_at - 1.day)..(happened_at + 1.day)).detect do |life_log|
        FamilyBrain::GroundedExtraction.normalize_text(life_log.summary) == normalized
      end
    end

    def validated_document_content(value)
      content = value.to_s.strip
      unless FamilyBrain::GroundedExtraction.meaningful_phrase?(content) &&
          FamilyBrain::GroundedExtraction.evidence_present?(@source_user_text, content)
        raise ArgumentError, error_message(:document_content_unverified)
      end

      content
    end

    def matching_document(title, content)
      normalized_title = FamilyBrain::GroundedExtraction.normalize_text(title)
      normalized_content = FamilyBrain::GroundedExtraction.normalize_text(content)
      @family.documents.detect do |document|
        FamilyBrain::GroundedExtraction.normalize_text(document.title) == normalized_title &&
          FamilyBrain::GroundedExtraction.normalize_text(document.content) == normalized_content
      end
    end

    def automation_trigger(action)
      trigger_type = action["automation_trigger_type"].to_s
      trigger_config = case trigger_type
      when "schedule_daily"
        { "time" => validated_automation_time(action["automation_trigger_time"]) }
      when "schedule_weekly"
        {
          "weekday" => validated_automation_weekday(action["automation_trigger_weekday"]),
          "time" => validated_automation_time(action["automation_trigger_time"])
        }
      when "schedule_monthly"
        {
          "day" => action["automation_trigger_day"].to_i.clamp(1, 31),
          "time" => validated_automation_time(action["automation_trigger_time"])
        }
      when "chat_keyword"
        keyword = action["automation_trigger_keyword"].to_s.strip.downcase
        raise ArgumentError, error_message(:automation_keyword_missing) if keyword.blank?
        unless FamilyBrain::GroundedExtraction.normalize_text(@source_user_text).include?(FamilyBrain::GroundedExtraction.normalize_text(keyword))
          raise ArgumentError, error_message(:automation_keyword_unverified)
        end

        {
          "keyword" => keyword,
          "match_mode" => normalized_match_mode(action["automation_match_mode"])
        }
      else
        raise ArgumentError, error_message(:automation_trigger_invalid)
      end

      [ trigger_type, trigger_config ]
    end

    def automation_action(action)
      action_type = action["automation_action_type"].to_s
      action_config = case action_type
      when "create_ai_note"
        { "content" => validated_automation_content(action["automation_action_content"]) }
      when "create_life_log"
        {
          "event_type" => normalized_life_log_type(action["event_type"]),
          "summary" => validated_automation_content(action["automation_action_content"]),
          "raw_text" => validated_automation_content(action["automation_action_content"]),
          "importance" => action["importance"].to_f.clamp(0.0, 1.0)
        }
      when "create_family_knowledge"
        {
          "key" => validated_knowledge_key(action["key"]),
          "value" => validated_automation_content(action["value"]),
          "source" => "automation_rule",
          "confidence" => action["confidence"].to_f.clamp(0.0, 1.0)
        }
      when "create_task"
        {
          "title" => validated_automation_title(action["automation_action_title"]),
          "description" => action["description"].to_s.presence,
          "priority" => action["priority"].to_i.clamp(1, 5),
          "status" => "pending",
          "assigned_to" => resolve_assignee_id(action["assignee_name"]),
          "due_in_days" => normalized_automation_offset(action["automation_offset_days"])
        }
      when "create_event"
        {
          "title" => validated_automation_title(action["automation_action_title"]),
          "location" => action["location"].to_s.presence,
          "source" => "automation_rule",
          "start_in_days" => normalized_automation_offset(action["automation_offset_days"]),
          "duration_hours" => action["automation_duration_hours"].to_i.clamp(1, 24)
        }
      when "create_reminder"
        {
          "title" => validated_automation_title(action["automation_action_title"]),
          "channel" => normalize_channel(action["automation_channel"]),
          "trigger_in_days" => normalized_automation_offset(action["automation_offset_days"])
        }
      else
        raise ArgumentError, error_message(:automation_action_invalid)
      end

      [ action_type, action_config ]
    end

    def validated_automation_time(value)
      time = value.to_s.strip
      raise ArgumentError, error_message(:automation_time_invalid) unless time.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)

      time
    end

    def validated_automation_weekday(value)
      weekday = value.to_s.strip.downcase
      raise ArgumentError, error_message(:automation_weekday_invalid) unless weekday.in?(%w[monday tuesday wednesday thursday friday saturday sunday])

      weekday
    end

    def normalized_match_mode(value)
      value.to_s.in?(%w[exact_command word contains]) ? value.to_s : "word"
    end

    def validated_automation_content(value)
      validated_evidence_value(value)
    end

    def validated_automation_title(value)
      title = FamilyBrain::GroundedExtraction.grounded_title(value, evidence_text_from_source)
      raise ArgumentError, error_message(:title_unverified) unless title

      title
    end

    def evidence_text_from_source
      @source_user_text
    end

    def normalized_automation_offset(value)
      value.to_i.clamp(0, 365)
    end

    def matching_automation_rule(name, trigger_type, trigger_config, action_type, action_config)
      normalized_name = FamilyBrain::GroundedExtraction.normalize_text(name)
      @family.automation_rules.detect do |rule|
        FamilyBrain::GroundedExtraction.normalize_text(rule.name) == normalized_name &&
          rule.trigger_type == trigger_type && rule.trigger_config == trigger_config &&
          rule.action_type == action_type && rule.action_config == action_config
      end
    end

    def normalized_same?(left, right)
      FamilyBrain::GroundedExtraction.normalize_text(left) == FamilyBrain::GroundedExtraction.normalize_text(right)
    end

    def evidence_text(action)
      Array(action["evidence"]).join(" ")
    end

    def find_matching_task(title)
      normalized = FamilyBrain::GroundedExtraction.normalize_text(title)
      @family.tasks.active.detect { |task| FamilyBrain::GroundedExtraction.normalize_text(task.title) == normalized }
    end

    def find_matching_reminder(title, trigger_at)
      normalized = FamilyBrain::GroundedExtraction.normalize_text(title)
      @family.reminders.active.detect do |reminder|
        FamilyBrain::GroundedExtraction.normalize_text(reminder.title) == normalized &&
          (reminder.trigger_at - trigger_at).abs < 1.minute
      end
    end

    def find_matching_event(title, start_at)
      normalized = FamilyBrain::GroundedExtraction.normalize_text(title)
      @family.events.where(start_time: (start_at - 1.minute)..(start_at + 1.minute)).detect do |event|
        FamilyBrain::GroundedExtraction.normalize_text(event.title) == normalized
      end
    end

    def resolve_assignee_id(name)
      normalized = FamilyBrain::GroundedExtraction.normalize_text(name)
      return if normalized.blank?

      @family.family_members.detect do |member|
        FamilyBrain::GroundedExtraction.normalize_text(member.name) == normalized
      end&.id
    end

    def normalize_channel(value)
      channel = value.to_s.strip
      Reminder::CHANNELS.include?(channel) ? channel : "app"
    end

    def normalized_task_status(value)
      status = value.to_s
      raise ArgumentError, "Unsupported task status" unless status.in?(Task::STATUSES)

      status
    end

    def normalized_reminder_status(value)
      status = value.to_s
      raise ArgumentError, "Unsupported reminder status" unless status.in?(Reminder::STATUSES)

      status
    end

    def changed?(action, field)
      Array(action["changed_fields"]).include?(field)
    end

    def action_fingerprint(action)
      normalized_action = action.sort.to_h.merge("evidence" => Array(action["evidence"]).sort)
      Digest::SHA256.hexdigest(normalized_action.to_json)
    end

    def find_or_initialize_effect(action, fingerprint)
      @family.ai_effects.find_or_initialize_by(
        source_ai_interaction: @user_message,
        action_fingerprint: fingerprint
      ).tap do |effect|
        effect.action_type ||= action.fetch("kind")
      end
    end

    def persist_effect!(effect, entity:, status:, message:)
      effect.update!(
        status: status,
        entity_type: entity&.class&.name,
        entity_id: entity&.id,
        details: nil,
        error_message: nil
      )
    end

    def persist_failed_effect(effect, action, fingerprint, error)
      failed_effect = effect || find_or_initialize_effect(action, fingerprint)
      failed_effect.update!(status: "failed", error_message: "#{error.class}: #{error.message}")
    rescue StandardError => logging_error
      Rails.logger.error("family_brain_effect_log_failed error=#{logging_error.class}: #{logging_error.message}")
    end

    def result_from_existing_effect(effect, action)
      entity = effect.entity
      status = effect.status == "completed" ? "already_completed" : "skipped"
      build_result(action, entity:, status:, message: action_message(:already_processed))
    end

    def build_result(action, entity:, status:, message:)
      Result.new(
        kind: action["kind"],
        status: status,
        entity_type: entity&.class&.name,
        entity_id: entity&.id,
        title: result_title(entity, action),
        message: message
      )
    end

    def result_title(entity, action)
      return entity.title if entity.respond_to?(:title)
      return entity.key if entity.respond_to?(:key)
      return entity.summary if entity.respond_to?(:summary)
      return entity.name if entity.respond_to?(:name)

      action["title"].presence || action["key"].presence || action["summary"].to_s
    end

    def action_message(key)
      FamilyBrain::LocaleCatalog.action_copy(@locale, key)
    end

    def error_message(key)
      FamilyBrain::LocaleCatalog.error_copy(@locale, key)
    end
  end
end
