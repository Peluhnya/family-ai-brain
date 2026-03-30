require "test_helper"

module FamilyBrain
  class AccountAiConfigTest < ActiveSupport::TestCase
    test "ollama app default uses local defaults without api key" do
      account = accounts(:one)
      account.ai_provider = "ollama"
      account.ai_access_mode = "app_default"
      account.ai_model = nil

      config = AccountAiConfig.new(account: account)

      assert_equal "ollama", config.provider
      assert_equal :ollama, config.ruby_llm_provider
      assert_equal AccountAiConfig::OLLAMA_DEFAULT_API_BASE, config.api_base
      assert_equal AccountAiConfig::OLLAMA_DEFAULT_CHAT_MODEL, config.chat_model
      assert_equal AccountAiConfig::OLLAMA_DEFAULT_EMBEDDING_MODEL, config.embedding_model
      assert_equal({ num_ctx: AccountAiConfig::OLLAMA_DEFAULT_NUM_CTX }, config.chat_params)
      assert_nil config.api_key
      assert_predicate config, :available?
    end

    test "openai compatible still uses openai ruby llm provider" do
      account = accounts(:one)
      account.ai_provider = "openai_compatible"
      account.ai_access_mode = "personal_api_key"
      account.ai_api_key = "test-key"
      account.ai_api_base = "https://example.com/v1"

      config = AccountAiConfig.new(account: account)

      assert_equal :openai, config.ruby_llm_provider
      assert_equal(
        { openai_api_key: "test-key", openai_api_base: "https://example.com/v1" },
        config.config_overrides
      )
    end
  end
end
