module FamilyBrain
  class RetrievalService
    KNOWLEDGE_LIMIT = 8
    LIFE_LOG_LIMIT = 6
    DOCUMENT_LIMIT = 6

    def initialize(family:, query:)
      @family = family
      @query = query.to_s
    end

    def relevant_knowledge
      return fallback_knowledge if @query.blank?

      query_embedding = FamilyBrain::EmbeddingService.embed(@query, account: @family.account)
      return fallback_knowledge if query_embedding.blank?

      @family.family_knowledge.where.not(embedding: nil)
        .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
        .limit(KNOWLEDGE_LIMIT)
    rescue StandardError
      fallback_knowledge
    end

    def relevant_life_logs
      return fallback_life_logs if @query.blank?

      query_embedding = FamilyBrain::EmbeddingService.embed(@query, account: @family.account)
      return fallback_life_logs if query_embedding.blank?

      @family.life_logs.where.not(embedding: nil)
        .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
        .limit(LIFE_LOG_LIMIT)
    rescue StandardError
      fallback_life_logs
    end

    def relevant_documents
      return fallback_documents if @query.blank?

      query_embedding = FamilyBrain::EmbeddingService.embed(@query, account: @family.account)
      return fallback_documents if query_embedding.blank?

      @family.documents.where.not(embedding: nil)
        .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
        .limit(DOCUMENT_LIMIT)
    rescue StandardError
      fallback_documents
    end

    private

    def fallback_knowledge
      @family.family_knowledge.priority_first.limit(KNOWLEDGE_LIMIT)
    end

    def fallback_life_logs
      @family.life_logs.priority_first.limit(LIFE_LOG_LIMIT)
    end

    def fallback_documents
      @family.documents.recent_first.limit(DOCUMENT_LIMIT)
    end
  end
end
