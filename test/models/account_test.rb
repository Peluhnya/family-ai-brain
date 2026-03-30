require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "supports ollama provider" do
    account = accounts(:one)
    account.ai_provider = "ollama"

    assert account.valid?
    assert_equal "Ollama", account.ai_provider_label
    assert_predicate account, :ollama?
  end

  test "rejects unsupported provider" do
    account = accounts(:one)
    account.ai_provider = "unknown"

    assert_not account.valid?
    assert_includes account.errors[:ai_provider], "is not included in the list"
  end
end
