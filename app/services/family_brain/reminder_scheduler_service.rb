module FamilyBrain
  class ReminderSchedulerService
    def initialize(family:, now: Time.current)
      @family = family
      @now = now.in_time_zone(family.timezone.presence || Time.zone.name)
    end

    def due_reminders
      @family.reminders.active.select { |reminder| due?(reminder) }
    end

    private

    def due?(reminder)
      reminder.trigger_at.present? && reminder.trigger_at.in_time_zone(@now.time_zone) <= @now
    end
  end
end
