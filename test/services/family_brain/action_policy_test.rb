require "test_helper"

module FamilyBrain
  class ActionPolicyTest < ActiveSupport::TestCase
    setup do
      @family = families(:one)
      @family.update!(timezone: "Europe/Berlin")
      @now = ActiveSupport::TimeZone["Europe/Berlin"].local(2026, 7, 22, 12)
    end

    test "adds a reminder to a deadline task" do
      actions = [ action(kind: "create_task", title: "Проплатити кредит", due_at: "2026-07-24T18:00:00+02:00") ]

      result = policy("до пʼятниці потрібно проплатити кредит").apply(actions)

      assert_equal %w[create_task create_reminder], result.map { |item| item["kind"] }
      assert_equal "2026-07-24T09:00:00+02:00", result.last["trigger_at"]
    end

    test "adds a previous-day reminder to a future event" do
      actions = [ action(kind: "create_event", title: "Табір Меланії", start_at: "2026-08-01T00:00:00+02:00", all_day: true) ]

      result = policy("Меланія 1 серпня іде в табір").apply(actions)

      assert_equal %w[create_event create_reminder], result.map { |item| item["kind"] }
      assert_equal "2026-07-31T18:00:00+02:00", result.last["trigger_at"]
    end

    test "respects only-reminder intent" do
      actions = [
        action(kind: "create_task", title: "Проплатити кредит", due_at: "2026-07-24T18:00:00+02:00"),
        action(kind: "create_reminder", title: "Проплатити кредит", trigger_at: "2026-07-24T10:00:00+02:00")
      ]

      result = policy("ні, тільки створити нагадування").apply(actions)

      assert_equal [ "create_reminder" ], result.map { |item| item["kind"] }
    end

    private

    def policy(text)
      ActionPolicy.new(family: @family, current_text: text, now: @now)
    end

    def action(overrides = {})
      {
        "kind" => "create_task",
        "record_id" => 0,
        "title" => "",
        "description" => "",
        "assignee_name" => "",
        "priority" => 3,
        "due_at" => "",
        "trigger_at" => "",
        "channel" => "app",
        "start_at" => "",
        "end_at" => "",
        "all_day" => false,
        "location" => "",
        "evidence" => [ "підтвердження користувача" ],
        "changed_fields" => []
      }.merge(overrides.stringify_keys)
    end
  end
end
