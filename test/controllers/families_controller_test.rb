require "test_helper"

class FamiliesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @family = families(:one)
  end

  test "should redirect guests from nested families index" do
    get account_families_url(@account)

    assert_redirected_to new_user_session_url
  end

  test "should redirect guests from family show" do
    get family_url(@family)

    assert_redirected_to new_user_session_url
  end
end
