module FamilyBrain
  class ReminderDeliveryService
    def initialize(reminder:)
      @reminder = reminder
      @family = reminder.family
    end

    def call
      case @reminder.channel
      when "app"
        deliver_app_notification
      when "email"
        deliver_email_notification
      when "sms"
        deliver_sms_notification
      else
        raise "Unsupported reminder channel: #{@reminder.channel}"
      end

      @reminder.update!(status: "sent")
    end

    private

    def deliver_app_notification
      @family.ai_interactions.create!(
        role: "assistant",
        content: "Reminder: #{@reminder.title}",
        model: "reminder-delivery"
      )
    end

    def deliver_email_notification
      @family.ai_interactions.create!(
        role: "assistant",
        content: "Email reminder queued: #{@reminder.title}",
        model: "reminder-delivery"
      )
    end

    def deliver_sms_notification
      @family.ai_interactions.create!(
        role: "assistant",
        content: "SMS reminder queued: #{@reminder.title}",
        model: "reminder-delivery"
      )
    end
  end
end
