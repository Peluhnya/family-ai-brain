class ReminderDeliveryJob < ApplicationJob
  queue_as :default

  def perform(reminder_id)
    reminder = Reminder.find(reminder_id)
    return unless reminder.pending?

    FamilyBrain::ReminderDeliveryService.new(reminder: reminder).call
  end
end
