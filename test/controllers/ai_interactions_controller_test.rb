require "test_helper"

class AiInteractionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:one)
    @family.update!(timezone: "Europe/Berlin")
    sign_in users(:one)
  end

  test "creates one daily conversation and links the assistant reply" do
    assert_difference -> { Conversation.count }, 1 do
      assert_difference -> { @family.ai_interactions.count }, 2 do
        assert_enqueued_with(job: GenerateAiAssistantReplyJob) do
          post family_ai_interactions_url(@family, format: :turbo_stream), params: {
            ai_interaction: { content: "Нагадай оплатити кредит" }
          }
        end
      end
    end

    assert_response :success
    user_message, assistant_message = @family.ai_interactions.order(:id).last(2)
    assert_equal user_message.conversation, assistant_message.conversation
    assert_equal @family.local_date, user_message.conversation.started_on
    assert_equal user_message, assistant_message.reply_to
    assert_select "turbo-stream[action='append'][target='chat_interactions']", count: 2
    assert_select "turbo-stream[action='replace'][target='conversation_#{@family.local_date.iso8601}_message_count']"
  end
end
