require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:one)
    @conversation = Conversation.for_family_at!(family: @family)
    sign_in users(:one)

    55.times do |index|
      @family.ai_interactions.create!(
        conversation: @conversation,
        role: "user",
        content: "History message #{index}"
      )
    end
  end

  test "prepends an older keyset page through turbo stream" do
    current_page = FamilyBrain::ConversationMessagePage.new(conversation: @conversation)

    get messages_family_conversation_url(
      @family,
      @conversation,
      before_id: current_page.before_id,
      format: :turbo_stream
    )

    assert_response :success
    assert_select "turbo-stream[action='prepend'][target='chat_interactions']", count: 1
    assert_select "turbo-stream[action='replace'][target='older_chat_messages']", count: 1
    assert_match "History message 0", response.body
    assert_no_match "History message 54", response.body
  end

  test "does not expose another account conversation" do
    sign_out users(:one)
    sign_in users(:two)

    get messages_family_conversation_url(
      @family,
      @conversation,
      before_id: @family.ai_interactions.maximum(:id),
      format: :turbo_stream
    )

    assert_response :not_found
  end
end
