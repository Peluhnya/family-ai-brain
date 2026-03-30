module FamilyBrain
  class ConnectionTestService
    def initialize(account:)
      @account = account
      @llm_client = FamilyBrain::LlmClient.new(account: account)
      @config = @llm_client.config
    end

    def call
      return failure("AI is not configured for this account.") unless @config.available?

      @llm_client.with_chat do |chat|
        response = chat
          .ask("Reply with exactly: OK")

        return success("Connection OK via #{@config.label}. Response: #{response.content.to_s.strip.first(80)}")
      end
    rescue StandardError => e
      failure("Connection failed: #{e.message}")
    end

    private

    def success(message)
      { ok: true, message: message }
    end

    def failure(message)
      { ok: false, message: message }
    end
  end
end
