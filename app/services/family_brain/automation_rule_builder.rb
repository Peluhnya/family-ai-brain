module FamilyBrain
  class AutomationRuleBuilder
    def initialize(params:)
      @params = params
    end

    def attributes
      base = {
        name: @params[:name],
        active: ActiveModel::Type::Boolean.new.cast(@params[:active]),
        template_key: @params[:template_key]
      }

      base.merge(template_payload)
    end

    private

    def template_payload
      case @params[:template_key]
      when "daily_ai_note"
        {
          trigger_type: "schedule_daily",
          trigger_config: { "time" => @params[:time_of_day].presence || "09:00" },
          action_type: "create_ai_note",
          action_config: { "content" => @params[:message_body].presence || "Daily family reminder." }
        }
      when "weekly_ai_note"
        {
          trigger_type: "schedule_weekly",
          trigger_config: {
            "weekday" => @params[:weekday].presence || "monday",
            "time" => @params[:time_of_day].presence || "09:00"
          },
          action_type: "create_ai_note",
          action_config: { "content" => @params[:message_body].presence || "Weekly family reminder." }
        }
      when "monthly_life_log"
        {
          trigger_type: "schedule_monthly",
          trigger_config: {
            "day" => @params[:day_of_month].presence.to_i.nonzero? || 1,
            "time" => @params[:time_of_day].presence || "09:00"
          },
          action_type: "create_life_log",
          action_config: {
            "event_type" => @params[:event_type].presence || "routine",
            "summary" => @params[:summary].presence || "Monthly automation note",
            "raw_text" => @params[:details].presence,
            "importance" => normalize_float(@params[:importance], default: 0.7)
          }
        }
      when "chat_keyword_knowledge"
        {
          trigger_type: "chat_keyword",
          trigger_config: { "keyword" => @params[:keyword].to_s.strip.downcase },
          action_type: "create_family_knowledge",
          action_config: {
            "key" => @params[:knowledge_key].presence || "captured_fact",
            "value" => @params[:knowledge_value].presence || "Captured from chat keyword",
            "source" => "automation_rule",
            "confidence" => normalize_float(@params[:confidence], default: 0.8)
          }
        }
      when "daily_task"
        {
          trigger_type: "schedule_daily",
          trigger_config: { "time" => @params[:time_of_day].presence || "09:00" },
          action_type: "create_task",
          action_config: task_action_config
        }
      when "chat_keyword_task"
        {
          trigger_type: "chat_keyword",
          trigger_config: { "keyword" => @params[:keyword].to_s.strip.downcase },
          action_type: "create_task",
          action_config: task_action_config
        }
      when "daily_event"
        {
          trigger_type: "schedule_daily",
          trigger_config: { "time" => @params[:time_of_day].presence || "09:00" },
          action_type: "create_event",
          action_config: event_action_config
        }
      when "chat_keyword_event"
        {
          trigger_type: "chat_keyword",
          trigger_config: { "keyword" => @params[:keyword].to_s.strip.downcase },
          action_type: "create_event",
          action_config: event_action_config
        }
      when "daily_reminder"
        {
          trigger_type: "schedule_daily",
          trigger_config: { "time" => @params[:time_of_day].presence || "09:00" },
          action_type: "create_reminder",
          action_config: reminder_action_config
        }
      when "chat_keyword_reminder"
        {
          trigger_type: "chat_keyword",
          trigger_config: { "keyword" => @params[:keyword].to_s.strip.downcase },
          action_type: "create_reminder",
          action_config: reminder_action_config
        }
      else
        {
          trigger_type: "schedule_daily",
          trigger_config: { "time" => "09:00" },
          action_type: "create_ai_note",
          action_config: { "content" => "Daily family reminder." }
        }
      end
    end

    def normalize_float(value, default:)
      parsed = value.to_f
      return default if parsed.zero? && value.to_s !~ /\A0(\.0+)?\z/

      parsed.clamp(0.0, 1.0)
    end

    def normalize_int(value, default:, min:, max:)
      parsed = value.to_i
      return default if parsed.zero? && value.to_s !~ /\A0+\z/

      parsed.clamp(min, max)
    end

    def task_action_config
      {
        "title" => @params[:task_title].presence || "Follow up family task",
        "description" => @params[:task_description].presence,
        "priority" => normalize_int(@params[:task_priority], default: 3, min: 1, max: 5),
        "status" => @params[:task_status].presence || "pending",
        "assigned_to" => @params[:task_assigned_to].presence,
        "due_in_days" => normalize_int(@params[:task_due_in_days], default: 0, min: 0, max: 365)
      }
    end

    def event_action_config
      {
        "title" => @params[:calendar_title].presence || "Family event",
        "location" => @params[:calendar_location].presence,
        "source" => @params[:calendar_source].presence || "automation_rule",
        "start_in_days" => normalize_int(@params[:calendar_start_in_days], default: 0, min: 0, max: 365),
        "duration_hours" => normalize_int(@params[:calendar_duration_hours], default: 1, min: 1, max: 24)
      }
    end

    def reminder_action_config
      {
        "title" => @params[:reminder_title].presence || "Family reminder",
        "channel" => @params[:reminder_channel].presence || "app",
        "trigger_in_days" => normalize_int(@params[:reminder_trigger_in_days], default: 0, min: 0, max: 365)
      }
    end
  end
end
