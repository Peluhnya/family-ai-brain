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

      normalized_actions.first(6)
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
        return unless action["all_day"] == true

        range = @date_parser.parse_range(evidence)
        return unless range

        action["start_at"] = range.first.iso8601
        action["end_at"] = range.last.iso8601
        action["all_day"] = true
      end
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
