require "test_helper"

module FamilyBrain
  class OrchestratorTest < ActiveSupport::TestCase
    FakePlanner = Struct.new(:plan, :source_user_text, :response_locale) do
      def call
        plan
      end
    end

    setup do
      @family = families(:one)
      @family.update!(timezone: "Europe/Berlin")
      @conversation = Conversation.for_family_at!(family: @family)
      @user = users(:one)
    end

    test "does not execute an incomplete reminder" do
      message = user_message("Нагадай купити молоко")
      planner = fake_planner(
        message,
        [ action(kind: "create_reminder", title: "Купити молоко", evidence: [ message.content ]) ],
        question: "Коли нагадати?"
      )

      result = Orchestrator.new(family: @family, user: @user, user_message: message, planner: planner).call

      assert_empty @family.reminders
      assert_equal "Коли нагадати?", result[:content]
      assert_equal "awaiting_clarification", @family.ai_action_proposals.last.state
      assert_empty result.dig(:orchestrator, :tool_results)
    end

    test "does not execute an inferred event before confirmation" do
      message = user_message("У пʼятницю о 10 прийом у лікаря")
      planner = fake_planner(
        message,
        [
          action(
            kind: "create_event",
            title: "Прийом у лікаря",
            start_at: "2026-07-24T10:00:00+02:00",
            intent_strength: "inferred",
            evidence: [ message.content ]
          )
        ],
        question: "Додати цю подію?"
      )

      result = Orchestrator.new(family: @family, user: @user, user_message: message, planner: planner).call

      assert_empty @family.events
      assert_equal "Додати цю подію?", result[:content]
      assert_equal "awaiting_confirmation", @family.ai_action_proposals.last.state
    end

    test "executes a complete explicit task and closes its proposal" do
      message = user_message("Додай задачу купити молоко")
      planner = fake_planner(
        message,
        [ action(kind: "create_task", title: "Купити молоко", evidence: [ message.content ]) ]
      )

      result = Orchestrator.new(family: @family, user: @user, user_message: message, planner: planner).call

      assert_equal 1, @family.tasks.count
      proposal = @family.ai_action_proposals.last
      assert_equal "completed", proposal.state
      assert_equal @family.tasks.last.id, proposal.entity_id
      assert_equal "created", result.dig(:orchestrator, :tool_results, 0, :status)
    end

    test "executes an independent ready action while keeping an incomplete one pending" do
      message = user_message("Додай задачу купити молоко і нагадай подзвонити мамі")
      planner = fake_planner(
        message,
        [
          action(kind: "create_task", title: "Купити молоко", evidence: [ message.content ]),
          action(kind: "create_reminder", title: "Подзвонити мамі", evidence: [ message.content ])
        ],
        question: "Коли нагадати подзвонити мамі?"
      )

      result = Orchestrator.new(family: @family, user: @user, user_message: message, planner: planner).call

      assert_equal 1, @family.tasks.count
      assert_empty @family.reminders
      assert_equal %w[completed awaiting_clarification], @family.ai_action_proposals.order(:id).last(2).map(&:state)
      assert result.dig(:orchestrator, :clarification_required)
    end

    test "completes the same pending proposal from a short follow-up" do
      original = user_message("Нагадай купити молоко")
      first_planner = fake_planner(
        original,
        [ action(kind: "create_reminder", title: "Купити молоко", evidence: [ original.content ]) ],
        question: "Коли нагадати?"
      )
      Orchestrator.new(family: @family, user: @user, user_message: original, planner: first_planner).call
      proposal = @family.ai_action_proposals.last

      follow_up = user_message("о 10")
      second_planner = FakePlanner.new(
        Planner::Plan.new(
          actions: [
            action(
              proposal_id: proposal.id,
              kind: "create_reminder",
              title: "Купити молоко",
              trigger_at: "2026-07-23T10:00:00+02:00",
              evidence: [ original.content, follow_up.content ]
            )
          ],
          clarification_question: "",
          error: nil
        ),
        [ original.content, follow_up.content ].join("\n"),
        "uk-UA"
      )

      Orchestrator.new(family: @family, user: @user, user_message: follow_up, planner: second_planner).call

      assert_equal 1, @family.reminders.count
      assert_equal proposal.id, @family.ai_action_proposals.last.id
      assert_equal "completed", proposal.reload.state
    end

    private

    def user_message(content)
      @family.ai_interactions.create!(
        conversation: @conversation,
        role: "user",
        content: content,
        user: @user,
        model: "human"
      )
    end

    def fake_planner(message, actions, question: "")
      FakePlanner.new(
        Planner::Plan.new(actions: actions, clarification_question: question, error: nil),
        message.content,
        "uk-UA"
      )
    end

    def action(overrides = {})
      {
        "proposal_id" => 0,
        "kind" => "create_task",
        "intent_strength" => "explicit",
        "record_id" => 0,
        "title" => "",
        "description" => "",
        "assignee_name" => "",
        "priority" => 3,
        "status" => "",
        "due_at" => "",
        "trigger_at" => "",
        "channel" => "app",
        "start_at" => "",
        "end_at" => "",
        "all_day" => false,
        "location" => "",
        "key" => "",
        "value" => "",
        "source" => "",
        "confidence" => 0.7,
        "event_type" => "",
        "summary" => "",
        "raw_text" => "",
        "importance" => 0.5,
        "happened_at" => "",
        "content" => "",
        "evidence" => [],
        "changed_fields" => [],
        "ambiguities" => []
      }.merge(overrides.stringify_keys)
    end
  end
end
