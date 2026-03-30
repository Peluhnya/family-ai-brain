class RunDueRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Family.includes(:reminders).find_each do |family|
      FamilyBrain::ReminderSchedulerService.new(family: family).due_reminders.each do |reminder|
        ReminderDeliveryJob.perform_later(reminder.id)
      end
    end
  end
end
