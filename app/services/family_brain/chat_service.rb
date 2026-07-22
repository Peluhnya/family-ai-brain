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
      system_prompt = prompt_builder.system_prompt
      prompt_metrics = prompt_builder.prompt_metrics
      short_term_messages = prompt_builder.short_term_messages.to_a
      response = @llm_client.with_chat do |chat|
        chat.with_instructions(system_prompt)

        short_term_messages.each do |interaction|
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
        tokens: extract_tokens(response),
        input_tokens: extract_input_tokens(response),
        output_tokens: extract_output_tokens(response),
        prompt_version: prompt_builder.prompt_version,
        usage_metadata: build_usage_metadata(
          prompt_metrics: prompt_metrics,
          short_term_messages: short_term_messages
        )
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

    def extract_input_tokens(response)
      return response.input_tokens.to_i if response.respond_to?(:input_tokens)

      nil
    end

    def extract_output_tokens(response)
      return response.output_tokens.to_i if response.respond_to?(:output_tokens)

      nil
    end

    def build_usage_metadata(prompt_metrics:, short_term_messages:)
      short_term_text = short_term_messages.map { |interaction| "#{interaction.role}: #{interaction.content}" }.join("\n")

      {
        sections: prompt_metrics[:sections],
        estimates: {
          system_prompt_tokens: prompt_metrics[:system_prompt_tokens],
          system_prompt_chars: prompt_metrics[:system_prompt_chars],
          short_term_tokens: FamilyBrain::TokenEstimator.estimate(short_term_text),
          short_term_message_count: short_term_messages.size,
          user_message_tokens: FamilyBrain::TokenEstimator.estimate(@message.content)
        }
      }
    end

    def fallback_response(content)
      {
        content: content,
        model: "local-fallback",
        tokens: nil,
        input_tokens: nil,
        output_tokens: nil,
        prompt_version: nil,
        usage_metadata: {}
      }
    end
  end
end
