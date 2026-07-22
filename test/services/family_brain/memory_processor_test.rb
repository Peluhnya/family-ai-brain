require "test_helper"

module FamilyBrain
  class MemoryProcessorTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test "does not independently re-extract knowledge or life logs after the planned turn" do
      family = families(:one)
      conversation = Conversation.for_family_at!(family: family)
      message = family.ai_interactions.create!(
        conversation: conversation,
        role: "user",
        content: "Наша сімʼя любить гори і вчора ми повернулися з подорожі",
        user: users(:one),
        model: "human"
      )

      assert_no_difference [ -> { family.family_knowledge.count }, -> { family.life_logs.count } ] do
        result = MemoryProcessor.new(family: family, user_message: message).call

        assert_empty result[:knowledge]
        assert_empty result[:life_logs]
      end
    end

    test "uses the configured safe keyword matching mode" do
      family = families(:one)
      conversation = Conversation.for_family_at!(family: family)
      rule = family.automation_rules.create!(
        name: "Allergy keyword",
        active: true,
        trigger_type: "chat_keyword",
        trigger_config: { "keyword" => "алергія", "match_mode" => "exact_command" },
        action_type: "create_ai_note",
        action_config: { "content" => "Check allergies" }
      )
      question = family.ai_interactions.create!(
        conversation: conversation,
        role: "user",
        content: "Яка в нас алергія?",
        user: users(:one),
        model: "human"
      )

      assert_no_enqueued_jobs only: AutomationRuleExecutionJob do
        MemoryProcessor.new(family: family, user_message: question).call
      end

      command = family.ai_interactions.create!(
        conversation: conversation,
        role: "user",
        content: "алергія",
        user: users(:one),
        model: "human"
      )
      assert_enqueued_with(job: AutomationRuleExecutionJob, args: ->(args) { args.first == rule.id }) do
        MemoryProcessor.new(family: family, user_message: command).call
      end
    end
  end
end
