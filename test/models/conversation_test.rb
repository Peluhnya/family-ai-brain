require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  setup do
    @family = families(:one)
    @family.update!(timezone: "Europe/Berlin")
    @zone = ActiveSupport::TimeZone["Europe/Berlin"]
  end

  test "reuses one conversation for the same local day" do
    morning = @zone.local(2026, 7, 22, 8)
    evening = @zone.local(2026, 7, 22, 21)

    first = Conversation.for_family_at!(family: @family, at: morning)
    second = Conversation.for_family_at!(family: @family, at: evening)

    assert_equal first, second
    assert_equal "22.07.2026", first.title
    assert_equal "active", first.status
  end

  test "starts a new conversation after local midnight and archives yesterday" do
    yesterday = Conversation.for_family_at!(family: @family, at: @zone.local(2026, 7, 22, 23, 59))
    today = Conversation.for_family_at!(family: @family, at: @zone.local(2026, 7, 23, 0, 1))

    assert_not_equal yesterday, today
    assert_equal "archived", yesterday.reload.status
    assert_equal "active", today.status
  end

  test "counts messages and links an assistant reply to its user message" do
    conversation = Conversation.for_family_at!(family: @family, at: @zone.local(2026, 7, 22, 12))
    user_message = @family.ai_interactions.create!(
      conversation: conversation,
      user: users(:one),
      role: "user",
      content: "Привіт"
    )
    assistant_message = @family.ai_interactions.create!(
      conversation: conversation,
      reply_to: user_message,
      role: "assistant",
      content: "Вітаю"
    )

    assert_equal 2, conversation.reload.messages_count
    assert_equal user_message, assistant_message.reply_to
    assert_equal assistant_message, user_message.reply
  end
end
