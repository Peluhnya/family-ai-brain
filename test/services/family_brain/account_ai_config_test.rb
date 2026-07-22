require "test_helper"

module FamilyBrain
  class AccountAiConfigTest < ActiveSupport::TestCase
    test "application default uses owner OpenAI settings" do
      account = accounts(:one)
      account.ai_provider = "ollama"
      account.ai_access_mode = "app_default"
      account.ai_model = nil
      account.valid?

      previous_api_key = ENV["OPENAI_API_KEY"]
      previous_chat_model = ENV["AI_CHAT_MODEL"]
      ENV["OPENAI_API_KEY"] = "app-key"
      ENV["AI_CHAT_MODEL"] = "gpt-4o-mini"
      config = AccountAiConfig.new(account: account)

      assert_equal "openai", config.provider
      assert_equal :openai, config.ruby_llm_provider
      assert_equal "gpt-4o-mini", config.chat_model
      assert_equal "app-key", config.api_key
      assert_empty config.chat_params
      assert_predicate config, :available?
    ensure
      ENV["OPENAI_API_KEY"] = previous_api_key
      ENV["AI_CHAT_MODEL"] = previous_chat_model
    end

    test "personal Ollama uses local defaults without api key" do
      account = accounts(:one)
      account.ai_provider = "ollama"
      account.ai_access_mode = "personal_api_key"
      account.ai_model = nil

      config = AccountAiConfig.new(account: account)

      assert_equal "ollama", config.provider
      assert_equal AccountAiConfig::OLLAMA_DEFAULT_API_BASE, config.api_base
      assert_equal AccountAiConfig::OLLAMA_DEFAULT_CHAT_MODEL, config.chat_model
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

module FamilyBrain
  class AccountAiConfigChatgptAccountTest < ActiveSupport::TestCase
    test "chatgpt account mode uses personal openai credentials" do
      account = accounts(:one)
      account.ai_access_mode = "chatgpt_account"
      account.ai_provider = "openai"
      account.ai_api_key = "sk-personal"
      account.ai_api_base = nil
      account.ai_model = "gpt-4o"

      config = AccountAiConfig.new(account: account)

      assert_equal "openai", config.provider
      assert_equal :openai, config.ruby_llm_provider
      assert_equal "sk-personal", config.api_key
      assert_equal "gpt-4o", config.chat_model
      assert_predicate config, :personal_configured?
      assert_predicate config, :available?
      assert_equal({ openai_api_key: "sk-personal", openai_api_base: nil }, config.config_overrides)
    end
  end
end
