module FamilyBrain
  class AutomationSchedulerService
    def initialize(family:, now: Time.current)
      @family = family
      @now = now.in_time_zone(family.timezone.presence || Time.zone.name)
    end

    def due_rules
      @family.automation_rules.where(active: true).select { |rule| due?(rule) }
    end

    private

    def due?(rule)
      case rule.trigger_type
      when "schedule_daily"
        time_matches?(rule.trigger_config["time"]) && not_run_today?(rule)
      when "schedule_weekly"
        weekday_matches?(rule.trigger_config["weekday"]) && time_matches?(rule.trigger_config["time"]) && not_run_this_week?(rule)
      when "schedule_monthly"
        day_matches?(rule.trigger_config["day"]) && time_matches?(rule.trigger_config["time"]) && not_run_this_month?(rule)
      else
        false
      end
    end

    def time_matches?(time_string)
      hour, minute = (time_string.presence || "09:00").split(":").map(&:to_i)
      @now.hour > hour || (@now.hour == hour && @now.min >= minute)
    end

    def weekday_matches?(weekday)
      @now.strftime("%A").downcase == weekday.to_s.downcase
    end

    def day_matches?(day)
      @now.day == day.to_i
    end

    def not_run_today?(rule)
      rule.last_executed_at.blank? || rule.last_executed_at.in_time_zone(@now.time_zone).to_date < @now.to_date
    end

    def not_run_this_week?(rule)
      rule.last_executed_at.blank? || rule.last_executed_at.in_time_zone(@now.time_zone) < @now.beginning_of_week
    end

    def not_run_this_month?(rule)
      rule.last_executed_at.blank? || rule.last_executed_at.in_time_zone(@now.time_zone) < @now.beginning_of_month
    end
  end
end
