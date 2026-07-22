require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should redirect guests from accounts index" do
    get accounts_url

    assert_redirected_to new_user_session_url
  end

  test "should redirect guests from new account" do
    get new_account_url

    assert_redirected_to new_user_session_url
  end

  test "should show ai usage statistics for tracked requests" do
    sign_in @user

    account = @user.accounts.create!(
      name: "Family Workspace",
      email: @user.email,
      active: true,
      ai_access_mode: "app_default",
      ai_provider: "openai"
    )
    family = account.families.create!(name: "Ivanenko", timezone: "Europe/Berlin", locale: "uk")
    family.ai_interactions.create!(
      role: "assistant",
      content: "Ось короткий план дій для сім'ї.",
      model: "gpt-4.1-mini",
      tokens: 960,
      input_tokens: 760,
      output_tokens: 200,
      system_prompt_tokens: 520,
      system_prompt_chars: 2100,
      short_term_tokens: 130,
      short_term_message_count: 4,
      user_message_tokens: 48,
      prompt_version: "v2_compact",
      llm_metadata: {
        sections: {
          documents: { tokens_estimate: 220 },
          family_knowledge: { tokens_estimate: 140 },
          tasks: { tokens_estimate: 80 }
        }
      }
    )

    get account_url(account)

    assert_response :success
    assert_match "Токени та prompt-статистика", response.body
    assert_match "960", response.body
    assert_match "v2_compact", response.body
    assert_match "Documents: ~220t", response.body
  end
end
