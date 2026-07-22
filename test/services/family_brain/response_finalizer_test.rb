require "test_helper"

module FamilyBrain
  class ResponseFinalizerTest < ActiveSupport::TestCase
    test "localizes the deterministic fallback to the current message language" do
      family = families(:one)
      family.update!(locale: "uk-UA")
      message = family.ai_interactions.create!(
        role: "user",
        content: "Erstelle eine Aufgabe: Kredit bezahlen",
        user: users(:one),
        model: "human"
      )
      plan = Planner::Plan.new(actions: [], clarification_question: "", error: nil)
      result = ToolExecutor::Result.new(
        kind: "create_task",
        status: "created",
        entity_type: "Task",
        entity_id: 1,
        title: "Kredit bezahlen",
        message: "Aufgabe erstellt."
      )
      finalizer = ResponseFinalizer.new(
        family: family,
        user: users(:one),
        user_message: message,
        plan: plan,
        tool_results: [ result ]
      )

      assert_equal "Erstellt: Kredit bezahlen.", finalizer.send(:deterministic_result_summary)
    end
  end
end
