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

  test "does not persist an empty conversation just by opening chat" do
    sign_in users(:one)

    assert_no_difference -> { @family.conversations.count } do
      get family_url(@family)
    end

    assert_response :success
    assert_select ".conversation-day", count: 1
    assert_select "form#ai_interaction_form"
  end

  test "calendar combines dated family records and repeats multi-day events" do
    sign_in users(:one)
    @family.update!(timezone: "UTC")
    event = @family.events.create!(
      title: "Сімейна подорож",
      start_time: Time.zone.parse("2026-07-10 09:00"),
      end_time: Time.zone.parse("2026-07-12 18:00"),
      source: "manual"
    )
    task = @family.tasks.create!(title: "Купити квитки", due_at: Time.zone.parse("2026-07-11 12:30"), status: "pending", priority: 3)
    @family.reminders.create!(title: "Взяти паспорти", trigger_at: Time.zone.parse("2026-07-10 08:00"), channel: "app", status: "pending")
    @family.life_logs.create!(event_type: "routine", summary: "Спланували маршрут", happened_at: Time.zone.parse("2026-07-09 20:00"), importance: 0.7)

    get tab_family_url(@family, tab: "calendar", month: "2026-07-01")

    assert_response :success
    assert_select "a.family-tab-link.active", text: /Календар/
    assert_select "article.calendar-day", count: 35
    assert_select "a.calendar-item-event[href='#{tab_family_path(@family, tab: "events")}##{ActionView::RecordIdentifier.dom_id(event)}']", count: 3
    assert_select "a.calendar-item-task", text: /12:30.*Купити квитки/
    assert_select "a.calendar-item-reminder", text: /Взяти паспорти/
    assert_select "a.calendar-item-log", text: /Спланували маршрут/
  end

  test "calendar falls back to the current month for an invalid month" do
    sign_in users(:one)

    get tab_family_url(@family, tab: "calendar", month: "not-a-date")

    assert_response :success
    assert_select "article.calendar-day"
  end

  test "moves ai diagnostics out of chat and into a paginated tab" do
    sign_in users(:one)

    11.times do |index|
      @family.ai_interactions.create!(
        role: "assistant",
        content: "Diagnostic response #{index}",
        model: "gpt-test",
        tokens: 100 + index,
        input_tokens: 80,
        output_tokens: 20,
        prompt_version: "test-v1",
        llm_metadata: { sections: { tasks: { tokens_estimate: 25 } } },
        created_at: index.minutes.ago
      )
    end

    get family_url(@family)

    assert_response :success
    assert_select "a", text: "AI журнал"
    assert_select "h2", text: "AI debug", count: 0

    get tab_family_url(@family, tab: "ai_logs")

    assert_response :success
    assert_select "h2", text: "AI журнал простору"
    assert_select "article.ai-log-entry", count: 10
    assert_select "nav.pagination-shell"
    assert_select "a[rel='next']"

    get tab_family_url(@family, tab: "ai_logs", log_type: "requests", page: 2),
      headers: { "Turbo-Frame" => "family_tab_content" }

    assert_response :success
    assert_select "turbo-frame#family_tab_content"
    assert_select "article.ai-log-entry", count: 1
    assert_select ".ai-log-range", text: /11–11 із 11/
    assert_select "a[rel='prev']"
  end

  test "shows assistant effects separately from llm requests" do
    sign_in users(:one)
    interaction = @family.ai_interactions.create!(
      role: "assistant",
      content: "Created a task",
      model: "gpt-test",
      prompt_version: "test-v1",
      llm_metadata: { sections: {} }
    )
    @family.ai_effects.create!(
      source_ai_interaction: interaction,
      action_type: "create_task",
      action_fingerprint: SecureRandom.hex(16),
      status: "failed",
      error_message: "Example failure"
    )

    get tab_family_url(@family, tab: "ai_logs", log_type: "effects")

    assert_response :success
    assert_select "h3", text: "Create task"
    assert_select ".log-status-failed", text: "Failed"
    assert_select ".ai-log-error", text: "Example failure"
  end

  test "shows only the latest fifty messages and makes older daily chats read only" do
    sign_in users(:one)
    @family.update!(timezone: "Europe/Berlin")
    today = @family.local_date
    yesterday = @family.conversations.create!(
      title: (today - 1.day).strftime("%d.%m.%Y"),
      started_on: today - 1.day,
      status: "archived",
      last_message_at: 1.day.ago
    )
    @family.ai_interactions.create!(
      conversation: yesterday,
      role: "user",
      content: "Yesterday only"
    )
    current = Conversation.for_family_at!(family: @family)
    55.times do |index|
      @family.ai_interactions.create!(conversation: current, role: "user", content: "Today #{index}")
    end

    get family_url(@family)

    assert_response :success
    assert_select ".conversation-day", count: 2
    assert_select ".chat-row-user", count: 50
    assert_select "#older_chat_messages a", text: "Завантажити попередні повідомлення"
    assert_no_match "Today 0<", response.body
    assert_match "Today 54", response.body

    get family_url(@family, conversation_id: yesterday.id), headers: { "Turbo-Frame" => "family_tab_content" }

    assert_response :success
    assert_select "turbo-frame#family_tab_content"
    assert_select ".archived-conversation-note"
    assert_select "form#ai_interaction_form", count: 0
    assert_match "Yesterday only", response.body
  end
end
