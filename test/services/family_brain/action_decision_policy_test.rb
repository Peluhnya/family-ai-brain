require "test_helper"

module FamilyBrain
  class ActionDecisionPolicyTest < ActiveSupport::TestCase
    test "allows a complete explicit task" do
      decision = policy.call(action(kind: "create_task", title: "Купити молоко"))

      assert_equal "ready", decision.state
      assert_empty decision.missing_fields
      assert_equal "low", decision.risk
    end

    test "requires confirmation for an inferred action" do
      decision = policy.call(action(
        kind: "create_event",
        title: "Прийом у лікаря",
        start_at: "2026-07-24T10:00:00+02:00",
        intent_strength: "inferred"
      ))

      assert_equal "awaiting_confirmation", decision.state
    end

    test "fails closed when intent strength is missing" do
      decision = policy.call(action(kind: "create_task", title: "Купити молоко", intent_strength: nil))

      assert_equal "awaiting_confirmation", decision.state
    end

    test "requires clarification for a reminder without a time" do
      decision = policy.call(action(kind: "create_reminder", title: "Купити молоко"))

      assert_equal "awaiting_clarification", decision.state
      assert_equal [ "trigger_at" ], decision.missing_fields
    end

    test "does not allow an update without a real target and changed fields" do
      decision = policy.call(action(kind: "update_task", record_id: 0, changed_fields: []))

      assert_equal "awaiting_clarification", decision.state
      assert_equal %w[record_id changed_fields], decision.missing_fields
    end

    test "always requires confirmation for a complete document" do
      decision = policy.call(action(
        kind: "create_document",
        title: "Сімейні правила",
        content: "Повний текст сімейних правил"
      ))

      assert_equal "awaiting_confirmation", decision.state
      assert_equal "high", decision.risk
    end

    test "requires missing automation schedule fields before confirmation" do
      decision = policy.call(action(
        kind: "create_automation_rule",
        title: "Щоденна перевірка",
        automation_trigger_type: "schedule_daily",
        automation_action_type: "create_task",
        automation_action_title: "Перевірити календар"
      ))

      assert_equal "awaiting_clarification", decision.state
      assert_equal [ "automation_trigger_time" ], decision.missing_fields
      assert_equal "high", decision.risk
    end

    private

    def policy
      @policy ||= ActionDecisionPolicy.new
    end

    def action(overrides = {})
      {
        "kind" => "create_task",
        "intent_strength" => "explicit",
        "record_id" => 0,
        "title" => "",
        "due_at" => "",
        "trigger_at" => "",
        "start_at" => "",
        "changed_fields" => [],
        "evidence" => [ "Підтвердження користувача" ],
        "ambiguities" => []
      }.merge(overrides.stringify_keys)
    end
  end
end
