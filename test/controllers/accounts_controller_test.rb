require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "should redirect guests from accounts index" do
    get accounts_url

    assert_redirected_to new_user_session_url
  end

  test "should redirect guests from new account" do
    get new_account_url

    assert_redirected_to new_user_session_url
  end
end
