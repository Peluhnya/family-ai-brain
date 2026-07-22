require "test_helper"

module FamilyBrain
  class ConversationMessagePageTest < ActiveSupport::TestCase
    setup do
      @family = families(:one)
      @conversation = Conversation.for_family_at!(family: @family)
    end

    test "returns the latest messages in chronological order and a keyset cursor" do
      55.times do |index|
        @family.ai_interactions.create!(
          conversation: @conversation,
          role: "user",
          content: "Message #{index}"
        )
      end

      first_page = ConversationMessagePage.new(conversation: @conversation)
      older_page = ConversationMessagePage.new(
        conversation: @conversation,
        before_id: first_page.before_id
      )

      assert_equal 50, first_page.messages.size
      assert first_page.has_older?
      assert_equal first_page.messages.sort_by(&:id), first_page.messages
      assert_equal 5, older_page.messages.size
      assert_not older_page.has_older?
      assert_operator older_page.messages.last.id, :<, first_page.messages.first.id
    end
  end
end
