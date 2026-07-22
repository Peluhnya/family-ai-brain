module FamilyBrain
  class ActionPolicy
    def initialize(family:, current_text:, now: Time.current, locale: nil)
      @family = family
      @current_text = current_text.to_s
      @zone = ActiveSupport::TimeZone[family.timezone.presence] || Time.zone
      @now = now.in_time_zone(@zone)
      @date_parser = FamilyBrain::TemporalParser.new(
        reference_time: @now,
        timezone: @zone.tzinfo.name,
        locale: locale || family.locale
      )
    end

    def apply(actions)
      normalized_actions = Array(actions).map(&:deep_dup)
      normalized_actions.each { |action| complete_temporal_fields!(action) }
      normalized_actions.reject! { |action| action["kind"] == "create_task" } if only_reminder?
      normalized_actions.reject! { |action| action["kind"] == "create_reminder" } if only_task? || no_reminder?

      companions = normalized_actions.filter_map do |action|
        case action["kind"]
        when "create_task"
          reminder_for_task(action, normalized_actions)
        when "create_event"
          reminder_for_event(action, normalized_actions)
        when "create_reminder"
          task_for_reminder(action, normalized_actions)
        end
      end

      (normalized_actions + companions).first(6)
    end

    private

    def complete_temporal_fields!(action)
      evidence = Array(action["evidence"]).join(" ")

      case action["kind"]
      when "create_task"
        action["due_at"] = @date_parser.parse_datetime(evidence, default_hour: 18, honor_clock: false)&.iso8601 if action["due_at"].blank?
      when "create_reminder"
        action["trigger_at"] = @date_parser.parse_datetime(evidence, default_hour: 9)&.iso8601 if action["trigger_at"].blank?
      when "create_event"
        return if action["start_at"].present?

        range = @date_parser.parse_range(evidence)
        return unless range

        action["start_at"] = range.first.iso8601
        action["end_at"] = range.last.iso8601
        action["all_day"] = true
      end
    end

    def reminder_for_task(task, actions)
      return if no_reminder? || only_task?
      return if task["due_at"].blank?
      return if related_action?(actions, "create_reminder", task)

      due_at = parse_iso(task["due_at"])
      return unless due_at

      action_template(
        kind: "create_reminder",
        title: task["title"],
        trigger_at: @zone.local(due_at.year, due_at.month, due_at.day, 9).iso8601,
        evidence: task["evidence"]
      )
    end

    def reminder_for_event(event, actions)
      return if no_reminder? || only_task?
      return if event["start_at"].blank?
      return if related_action?(actions, "create_reminder", event)

      start_at = parse_iso(event["start_at"])
      return unless start_at && start_at > @now

      trigger_at = (start_at.beginning_of_day - 1.day).change(hour: 18)
      action_template(
        kind: "create_reminder",
        title: event["title"],
        trigger_at: trigger_at.iso8601,
        evidence: event["evidence"]
      )
    end

    def task_for_reminder(reminder, actions)
      return if only_reminder?
      return unless FamilyBrain::GroundedExtraction.actionable?(@current_text)
      return if related_action?(actions, "create_task", reminder)

      action_template(
        kind: "create_task",
        title: reminder["title"],
        due_at: reminder["trigger_at"],
        evidence: reminder["evidence"]
      )
    end

    def related_action?(actions, kind, source)
      actions.any? do |candidate|
        next false unless candidate["kind"] == kind

        same_evidence = (Array(candidate["evidence"]) & Array(source["evidence"])).any?
        titles_related = FamilyBrain::GroundedExtraction.title_grounded_in_evidence?(candidate["title"], source["title"]) ||
          FamilyBrain::GroundedExtraction.title_grounded_in_evidence?(source["title"], candidate["title"])
        same_evidence && titles_related
      end
    end

    def action_template(kind:, title:, evidence:, due_at: "", trigger_at: "")
      {
        "kind" => kind,
        "record_id" => 0,
        "title" => title.to_s,
        "description" => "",
        "assignee_name" => "",
        "priority" => 3,
        "due_at" => due_at,
        "trigger_at" => trigger_at,
        "channel" => "app",
        "start_at" => "",
        "end_at" => "",
        "all_day" => false,
        "location" => "",
        "evidence" => Array(evidence),
        "changed_fields" => []
      }
    end

    def parse_iso(value)
      Time.iso8601(value.to_s).in_time_zone(@zone)
    rescue ArgumentError
      nil
    end

    def only_reminder?
      FamilyBrain::GroundedExtraction.only_reminder?(@current_text)
    end

    def only_task?
      FamilyBrain::GroundedExtraction.only_task?(@current_text)
    end

    def no_reminder?
      FamilyBrain::GroundedExtraction.no_reminder?(@current_text)
    end
  end
end
