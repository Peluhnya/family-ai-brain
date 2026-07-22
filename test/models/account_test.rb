require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "supports ollama provider" do
    account = accounts(:one)
    account.ai_access_mode = "personal_api_key"
    account.ai_provider = "ollama"

    assert account.valid?
    assert_equal "Ollama", account.ai_provider_label
    assert_predicate account, :ollama?
  end

  test "rejects unsupported provider" do
    account = accounts(:one)
    account.ai_access_mode = "personal_api_key"
    account.ai_provider = "unknown"

    assert_not account.valid?
    assert_includes account.errors[:ai_provider], "is not included in the list"
  end

  test "labels OpenAI API key mode without implying ChatGPT session access" do
    account = accounts(:one)
    account.ai_access_mode = "chatgpt_account"

    assert_equal "Мій OpenAI API key", account.ai_access_mode_label
  end

  test "normalizes application default mode to OpenAI" do
    account = accounts(:one)
    account.ai_access_mode = "app_default"
    account.ai_provider = "ollama"

    assert account.valid?
    assert_equal "openai", account.ai_provider
  end

  test "normalizes a custom model id selected in the form" do
    account = accounts(:one)
    account.ai_access_mode = "personal_api_key"
    account.ai_provider = "ollama"
    account.ai_model = FamilyBrain::AiModelCatalog::CUSTOM_MODEL_VALUE
    account.ai_model_custom = "  llama3.3:latest  "

    assert account.valid?
    assert_equal "llama3.3:latest", account.ai_model
  end

  test "requires an API key for a personal OpenAI connection" do
    account = accounts(:one)
    account.ai_access_mode = "chatgpt_account"
    account.ai_api_key = nil

    assert_not account.valid?
    assert_includes account.errors[:ai_api_key], "can't be blank"
  end

  test "AI model catalog provides guided defaults" do
    assert_equal "gpt-4o-mini", FamilyBrain::AiModelCatalog.default_for("openai")
    assert FamilyBrain::AiModelCatalog.known_model?("openai", "gpt-5.4-mini")
    assert FamilyBrain::AiModelCatalog.known_model?("ollama", "gemma3:1b")
    assert_not FamilyBrain::AiModelCatalog.known_model?("ollama", "custom-model")
  end
end
