module FamilyBrain
  class EmbeddingService
    def self.embed(text, account:)
      return if text.blank?
      llm_client = FamilyBrain::LlmClient.new(account: account)
      return unless llm_client.available?

      embedding = llm_client.embed(text)
      vector = embedding.vectors

      return vector if vector.is_a?(Array) && vector.first.is_a?(Float)
      return vector.first if vector.is_a?(Array) && vector.first.is_a?(Array)

      nil
    rescue StandardError => error
      Rails.logger.warn("family_brain_embedding_failed error=#{error.class}: #{error.message}")
      nil
    end
  end
end
