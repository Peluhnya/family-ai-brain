module FamilyBrain
  class ConversationMessagePage
    PAGE_SIZE = 50

    attr_reader :messages

    def initialize(conversation:, before_id: nil, page_size: PAGE_SIZE)
      scope = conversation.ai_interactions.includes(:user)
      scope = scope.where(id: ...before_id.to_i) if before_id.present?
      records = scope.order(id: :desc).limit(page_size + 1).to_a

      @has_older = records.size > page_size
      @messages = records.first(page_size).reverse
    end

    def has_older?
      @has_older
    end

    def before_id
      messages.first&.id
    end
  end
end
