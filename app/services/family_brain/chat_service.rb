module FamilyBrain
  class ChatService
    def initialize(family:, user:, message:)
      @family = family
      @user = user
      @message = message
      @llm_client = FamilyBrain::LlmClient.new(account: @family.account)
      @account_ai_config = @llm_client.config
    end

    def call
      return fallback_response("AI provider is not configured for this account. Add provider settings in account settings.") unless @account_ai_config.available?

      prompt_builder = FamilyBrain::PromptBuilder.new(family: @family, current_message: @message)
      response = @llm_client.with_chat do |chat|
        chat.with_instructions(prompt_builder.system_prompt)

        prompt_builder.short_term_messages.each do |interaction|
          chat.add_message(role: interaction.role.to_sym, content: interaction.content)
        end

        if block_given?
          chat.ask(@message.content) do |chunk|
            yield chunk
          end
        else
          chat.ask(@message.content)
        end
      end

      {
        content: response.content,
        model: extract_model(response),
        tokens: extract_tokens(response)
      }
    rescue StandardError => e
      fallback_response("LLM request failed: #{e.message}")
    end

    private

    def extract_model(response)
      response.respond_to?(:model_id) ? response.model_id : @account_ai_config.chat_model
    end

    def extract_tokens(response)
      return response.input_tokens.to_i + response.output_tokens.to_i if response.respond_to?(:input_tokens) && response.respond_to?(:output_tokens)
      return response.tokens.to_i if response.respond_to?(:tokens)

      nil
    end

    def fallback_response(content)
      {
        content: content,
        model: "local-fallback",
        tokens: nil
      }
    end
  end
end
