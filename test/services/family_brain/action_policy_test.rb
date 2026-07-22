require "test_helper"

module FamilyBrain
  class ActionPolicyTest < ActiveSupport::TestCase
    setup do
      @family = families(:one)
      @family.update!(timezone: "Europe/Berlin")
      @now = ActiveSupport::TimeZone["Europe/Berlin"].local(2026, 7, 22, 12)
    end

    test "does not silently add a reminder to a deadline task" do
      actions = [ action(kind: "create_task", title: "Проплатити кредит", due_at: "2026-07-24T18:00:00+02:00") ]

      result = policy("до пʼятниці потрібно проплатити кредит").apply(actions)

      assert_equal [ "create_task" ], result.map { |item| item["kind"] }
    end

    test "does not silently add a previous-day reminder to a future event" do
      actions = [ action(kind: "create_event", title: "Табір Меланії", start_at: "2026-08-01T00:00:00+02:00", all_day: true) ]

      result = policy("Меланія 1 серпня іде в табір").apply(actions)

      assert_equal [ "create_event" ], result.map { |item| item["kind"] }
    end

    test "respects only-reminder intent" do
      actions = [
        action(kind: "create_task", title: "Проплатити кредит", due_at: "2026-07-24T18:00:00+02:00"),
        action(kind: "create_reminder", title: "Проплатити кредит", trigger_at: "2026-07-24T10:00:00+02:00")
      ]

      result = policy("ні, тільки створити нагадування").apply(actions)

      assert_equal [ "create_reminder" ], result.map { |item| item["kind"] }
    end

    test "respects German only-reminder intent" do
      @family.update!(locale: "de-DE")
      actions = [
        action(kind: "create_task", title: "Kredit bezahlen", due_at: "2026-07-24T18:00:00+02:00"),
        action(kind: "create_reminder", title: "Kredit bezahlen", trigger_at: "2026-07-24T10:00:00+02:00")
      ]

      result = policy("Nein, nur eine Erinnerung").apply(actions)

      assert_equal [ "create_reminder" ], result.map { |item| item["kind"] }
    end

    test "does not silently add a task for an actionable English reminder" do
      @family.update!(locale: "en-GB")
      evidence = "Remind me tomorrow to pay the loan"
      actions = [ action(kind: "create_reminder", title: "Pay the loan", evidence: [ evidence ]) ]

      result = policy(evidence).apply(actions)

      assert_equal [ "create_reminder" ], result.map { |item| item["kind"] }
      assert_equal "2026-07-23T09:00:00+02:00", result.first["trigger_at"]
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
