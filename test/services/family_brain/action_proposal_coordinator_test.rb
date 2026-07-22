require "test_helper"

module FamilyBrain
  class ActionProposalCoordinatorTest < ActiveSupport::TestCase
    setup do
      @family = families(:one)
      @family.update!(timezone: "Europe/Berlin")
      @conversation = Conversation.for_family_at!(family: @family)
      @message = user_message("Нагадай купити молоко")
      @now = Time.zone.local(2026, 7, 22, 12)
    end

    test "persists an incomplete action without making it executable" do
      outcome = coordinator(@message).call(
        [ action(kind: "create_reminder", title: "Купити молоко", evidence: [ @message.content ]) ],
        planner_question: "Коли нагадати?"
      )

      assert_empty outcome.ready_actions
      assert_equal 1, outcome.pending_proposals.size
      proposal = outcome.pending_proposals.first
      assert_equal "awaiting_clarification", proposal.state
      assert_equal [ "trigger_at" ], proposal.missing_fields
      assert_equal "Коли нагадати?", outcome.clarification_question
    end

    test "persists an inferred complete action for confirmation" do
      outcome = coordinator(@message).call([
        action(
          kind: "create_event",
          title: "Прийом у лікаря",
          start_at: "2026-07-24T10:00:00+02:00",
          intent_strength: "inferred",
          evidence: [ @message.content ]
        )
      ])

      assert_empty outcome.ready_actions
      assert_equal "awaiting_confirmation", outcome.pending_proposals.first.state
    end

    test "a follow-up can complete the referenced pending proposal" do
      first = coordinator(@message).call([
        action(kind: "create_reminder", title: "Купити молоко", evidence: [ @message.content ])
      ]).pending_proposals.first
      follow_up = user_message("о 10")

      outcome = coordinator(follow_up).call([
        action(
          proposal_id: first.id,
          kind: "create_reminder",
          title: "Купити молоко",
          trigger_at: "2026-07-23T10:00:00+02:00",
          evidence: [ @message.content, follow_up.content ]
        )
      ])

      assert_equal 1, outcome.ready_actions.size
      assert_empty outcome.pending_proposals
      assert_equal first.id, outcome.ready_actions.first.proposal.id
      assert_equal follow_up.id, first.reload.confirmation_ai_interaction_id
    end

    test "records assistant provenance only for a document proposal" do
      assistant = @family.ai_interactions.create!(
        conversation: @conversation,
        role: "assistant",
        content: "Правило перше: завжди перевіряти сімейний календар",
        model: "test"
      )
      request = user_message("Збережи це як документ Сімейні правила")

      proposal = coordinator(request).call([
        action(
          kind: "create_document",
          title: "Сімейні правила",
          content: assistant.content,
          evidence: [ request.content, assistant.content ]
        )
      ]).pending_proposals.first

      assert_equal "awaiting_confirmation", proposal.state
      assert_equal %w[user assistant], proposal.evidence_data.map { |item| item["source_role"] }
    end

    test "does not accept assistant content without user authorization evidence" do
      assistant = @family.ai_interactions.create!(
        conversation: @conversation,
        role: "assistant",
        content: "Правило: перевіряти календар щовечора",
        model: "test"
      )
      request = user_message("так")

      proposal = coordinator(request).call([
        action(
          kind: "create_document",
          title: "Правило календаря",
          content: assistant.content,
          evidence: [ assistant.content ]
        )
      ]).pending_proposals.first

      assert_equal "awaiting_clarification", proposal.state
      assert_includes proposal.missing_fields, "evidence"
    end

    test "refuses to update an imported calendar event" do
      event = @family.events.create!(
        title: "Зовнішня зустріч",
        start_time: 2.days.from_now,
        end_time: 2.days.from_now + 1.hour,
        source: "google_calendar",
        source_key: "google_calendar",
        external_id: "external-1"
      )
      request = user_message("Перенеси зовнішню зустріч на завтра")

      proposal = coordinator(request).call([
        action(
          kind: "update_event",
          record_id: event.id,
          title: event.title,
          start_at: 1.day.from_now.iso8601,
          evidence: [ request.content ],
          changed_fields: [ "start_at" ]
        )
      ]).pending_proposals.first

      assert_equal "awaiting_clarification", proposal.state
      assert_includes proposal.missing_fields, "external_event_read_only"
    end

    test "allows an active-only automation update to reach confirmation without rebuilding configs" do
      rule = @family.automation_rules.create!(
        name: "Щоденна задача",
        active: true,
        trigger_type: "schedule_daily",
        trigger_config: { "time" => "09:00" },
        action_type: "create_task",
        action_config: { "title" => "Перевірити календар" }
      )
      request = user_message("Вимкни щоденну автоматизацію")

      proposal = coordinator(request).call([
        action(
          kind: "update_automation_rule",
          record_id: rule.id,
          title: rule.name,
          active: false,
          evidence: [ request.content ],
          changed_fields: [ "active" ]
        )
      ]).pending_proposals.first

      assert_equal "awaiting_confirmation", proposal.state
      assert_empty proposal.missing_fields
    end

    private

    def coordinator(message)
      ActionProposalCoordinator.new(
        family: @family,
        user_message: message,
        locale: "uk-UA",
        now: @now
      )
    end

    def user_message(content)
      @family.ai_interactions.create!(
        conversation: @conversation,
        role: "user",
        content: content,
        user: users(:one),
        model: "human"
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
        "due_at" => "",
        "trigger_at" => "",
        "channel" => "app",
        "start_at" => "",
        "end_at" => "",
        "all_day" => false,
        "location" => "",
        "content" => "",
        "evidence" => [],
        "changed_fields" => [],
        "ambiguities" => []
      }.merge(overrides.stringify_keys)
    end
  end
end
