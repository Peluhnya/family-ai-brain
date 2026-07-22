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

    def initialize(family:, user_message:, source_user_text:, now: Time.current)
      @family = family
      @user_message = user_message
      @source_user_text = source_user_text.to_s
      @zone = ActiveSupport::TimeZone[family.timezone.presence] || Time.zone
      @now = now.in_time_zone(@zone)
      @date_parser = FamilyBrain::UkrainianDateParser.new(reference_time: @now, timezone: @zone.tzinfo.name)
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
      else raise ArgumentError, "Unsupported action #{action['kind']}"
      end
    end

    def create_task(action)
      validate_title!(action)
      due_at = parse_time(action["due_at"], fallback_text: evidence_text(action), default_hour: 18, honor_fallback_clock: false)
      existing = find_matching_task(action["title"])
      return [ existing, "skipped", "Відповідна активна задача вже існує." ] if existing

      task = @family.tasks.create!(
        title: action["title"].strip,
        description: action["description"].to_s.strip.presence,
        assigned_to: resolve_assignee_id(action["assignee_name"]),
        due_at: due_at,
        status: "pending",
        priority: action["priority"].to_i.clamp(1, 5)
      )
      [ task, "created", "Задачу створено." ]
    end

    def update_task(action)
      task = @family.tasks.find(action["record_id"])
      attributes = {}
      attributes[:title] = action["title"].strip if changed?(action, "title") && action["title"].present?
      attributes[:description] = action["description"].strip if changed?(action, "description")
      attributes[:assigned_to] = resolve_assignee_id(action["assignee_name"]) if changed?(action, "assignee_name")
      attributes[:priority] = action["priority"].to_i.clamp(1, 5) if changed?(action, "priority")
      attributes[:due_at] = parse_time(action["due_at"], fallback_text: evidence_text(action), default_hour: 18, honor_fallback_clock: false) if changed?(action, "due_at")
      return [ task, "skipped", "У задачі немає нових даних для оновлення." ] if attributes.empty?

      task.update!(attributes)
      [ task, "updated", "Задачу оновлено." ]
    end

    def create_reminder(action)
      validate_title!(action)
      trigger_at = parse_time(action["trigger_at"], fallback_text: evidence_text(action), default_hour: 9)
      raise ArgumentError, "Не вдалося визначити час нагадування." unless trigger_at

      existing = find_matching_reminder(action["title"], trigger_at)
      return [ existing, "skipped", "Відповідне активне нагадування вже існує." ] if existing

      reminder = @family.reminders.create!(
        title: action["title"].strip,
        trigger_at: trigger_at,
        channel: normalize_channel(action["channel"]),
        status: "pending"
      )
      [ reminder, "created", "Нагадування створено." ]
    end

    def update_reminder(action)
      reminder = @family.reminders.find(action["record_id"])
      attributes = {}
      attributes[:title] = action["title"].strip if changed?(action, "title") && action["title"].present?
      attributes[:trigger_at] = parse_time(action["trigger_at"], fallback_text: evidence_text(action), default_hour: 9) if changed?(action, "trigger_at")
      attributes[:channel] = normalize_channel(action["channel"]) if changed?(action, "channel")
      return [ reminder, "skipped", "У нагадуванні немає нових даних для оновлення." ] if attributes.compact.empty?

      reminder.update!(attributes.compact)
      [ reminder, "updated", "Нагадування оновлено." ]
    end

    def create_event(action)
      validate_title!(action)
      start_at, end_at = event_times(action)
      raise ArgumentError, "Не вдалося визначити початок події." unless start_at

      existing = find_matching_event(action["title"], start_at)
      return [ existing, "skipped", "Відповідна подія вже існує." ] if existing

      event = @family.events.create!(
        title: action["title"].strip,
        location: action["location"].to_s.strip.presence,
        source: "ai_chat",
        start_time: start_at,
        end_time: end_at,
        all_day: action["all_day"]
      )
      [ event, "created", "Подію створено." ]
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
      return [ event, "skipped", "У події немає нових даних для оновлення." ] if attributes.empty?

      event.update!(attributes)
      [ event, "updated", "Подію оновлено." ]
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
      raise ArgumentError, "Кінець події має бути після початку." if end_at <= start_at

      [ start_at, end_at ]
    end

    def parse_time(value, fallback_text:, default_hour:, honor_fallback_clock: true)
      parsed = @date_parser.parse_datetime(value, default_hour: default_hour) if value.present?
      parsed || (@date_parser.parse_datetime(fallback_text, default_hour: default_hour, honor_clock: honor_fallback_clock) if fallback_text.present?)
    end

    def validate_title!(action)
      title = action["title"].to_s.strip
      raise ArgumentError, "Назва дії порожня." unless FamilyBrain::GroundedExtraction.meaningful_phrase?(title)
      raise ArgumentError, "Назва дії не підтверджена повідомленням користувача." unless FamilyBrain::GroundedExtraction.title_grounded_in_evidence?(title, evidence_text(action))
    end

    def validate_evidence!(action)
      quotes = Array(action["evidence"]).map(&:to_s).reject(&:blank?)
      raise ArgumentError, "Дія не має підтвердження в повідомленні користувача." if quotes.empty?

      missing_quote = quotes.find { |quote| !FamilyBrain::GroundedExtraction.evidence_present?(@source_user_text, quote) }
      raise ArgumentError, "Підтвердження дії відсутнє в повідомленнях користувача." if missing_quote
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
        details: { message: message }.to_json,
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
      build_result(action, entity:, status:, message: "Цю дію вже було оброблено.")
    end

    def build_result(action, entity:, status:, message:)
      Result.new(
        kind: action["kind"],
        status: status,
        entity_type: entity&.class&.name,
        entity_id: entity&.id,
        title: entity.respond_to?(:title) ? entity.title : action["title"].to_s,
        message: message
      )
    end
  end
end
