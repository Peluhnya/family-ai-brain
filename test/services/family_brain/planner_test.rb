require "test_helper"

module FamilyBrain
  class PlannerTest < ActiveSupport::TestCase
    test "provides recent user context current time timezone and existing records" do
      family = families(:one)
      family.update!(timezone: "Europe/Berlin")
      previous = family.ai_interactions.create!(role: "user", content: "до пʼятниці сплатити кредит", user: users(:one), model: "human")
      family.ai_interactions.create!(role: "assistant", content: "О котрій нагадати?", model: "test")
      family.tasks.create!(title: "Сплатити кредит", status: "pending", priority: 5)
      current = family.ai_interactions.create!(role: "user", content: "о 10 ранку", user: users(:one), model: "human")
      payload = {
        "actions" => [
          {
            "kind" => "create_reminder",
            "record_id" => 0,
            "title" => "Сплатити кредит",
            "description" => "",
            "assignee_name" => "",
            "priority" => 3,
            "due_at" => "",
            "trigger_at" => "2026-07-24T10:00:00+02:00",
            "channel" => "app",
            "start_at" => "",
            "end_at" => "",
            "all_day" => false,
            "location" => "",
            "evidence" => [ previous.content, current.content ],
            "changed_fields" => []
          }
        ],
        "clarification_question" => ""
      }
      client = FakeStructuredLlmClient.new(payload)
      now = ActiveSupport::TimeZone["Europe/Berlin"].local(2026, 7, 22, 12)

      planner = Planner.new(family: family, user_message: current, llm_client: client, now: now)
      plan = planner.call

      assert_equal 1, plan.actions.size
      assert_includes planner.source_user_text, "до пʼятниці сплатити кредит"
      assert_includes planner.source_user_text, "о 10 ранку"
      assert_includes client.prompts.first, "2026-07-22T12:00:00+02:00"
      assert_includes client.prompts.first, "timezone: Europe/Berlin"
      assert_includes client.prompts.first, "О котрій нагадати?"
      assert_includes client.prompts.first, "task #{family.tasks.last.id}"
    end

    test "requests German output for a German message" do
      family = families(:one)
      family.update!(timezone: "Europe/Berlin", locale: "uk-UA")
      current = family.ai_interactions.create!(role: "user", content: "Erinnere mich morgen um 10 Uhr", user: users(:one), model: "human")
      client = FakeStructuredLlmClient.new({ "actions" => [], "clarification_question" => "" })

      Planner.new(family: family, user_message: current, llm_client: client, now: Time.zone.local(2026, 7, 22, 12)).call

      assert_includes client.prompts.first, "de-DE (German)"
      assert_includes client.prompts.first, "Use this language for titles and clarification questions"
    end

    test "inherits language from recent user context for a short follow-up" do
      family = families(:one)
      family.update!(timezone: "Europe/Berlin", locale: "uk-UA")
      family.ai_interactions.create!(role: "user", content: "Remind me tomorrow to pay the loan", user: users(:one), model: "human")
      current = family.ai_interactions.create!(role: "user", content: "10:30", user: users(:one), model: "human")
      client = FakeStructuredLlmClient.new({ "actions" => [], "clarification_question" => "" })

      Planner.new(family: family, user_message: current, llm_client: client, now: Time.zone.local(2026, 7, 22, 12)).call

      assert_includes client.prompts.first, "en-GB (British English)"
    end
  end
end
