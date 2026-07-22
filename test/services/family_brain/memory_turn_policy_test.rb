require "test_helper"

module FamilyBrain
  class MemoryTurnPolicyTest < ActiveSupport::TestCase
    setup do
      @family = families(:one)
    end

    test "skips memory when the planner handled an action in any language" do
      assistant = assistant_message(
        "actions_planned" => 2,
        "tool_results" => [ { "kind" => "create_event", "status" => "created" } ],
        "clarification_required" => false,
        "planning_error" => nil
      )

      assert_not MemoryTurnPolicy.new(assistant_message: assistant).extractable?
    end

    test "skips memory while an operational request needs clarification" do
      assistant = assistant_message(
        "actions_planned" => 0,
        "tool_results" => [],
        "clarification_required" => true,
        "planning_error" => nil
      )

      assert_not MemoryTurnPolicy.new(assistant_message: assistant).extractable?
    end

    test "allows memory extraction after a normal conversational reply" do
      assistant = assistant_message(
        "actions_planned" => 0,
        "tool_results" => [],
        "clarification_required" => false,
        "planning_error" => nil
      )

      assert MemoryTurnPolicy.new(assistant_message: assistant).extractable?
    end

    test "fails closed when an assistant response has no orchestrator audit" do
      assistant = @family.ai_interactions.create!(role: "assistant", content: "Fallback", llm_metadata: {})

      assert_not MemoryTurnPolicy.new(assistant_message: assistant).extractable?
    end

    private

    def assistant_message(orchestrator)
      @family.ai_interactions.create!(
        role: "assistant",
        content: "Processed",
        llm_metadata: { "orchestrator" => orchestrator }
      )
    end
  end
end
