require "test_helper"

module FamilyBrain
  class ToolExecutorTest < ActiveSupport::TestCase
    setup do
      @family = families(:one)
      @family.update!(timezone: "Europe/Berlin")
      @zone = ActiveSupport::TimeZone["Europe/Berlin"]
      @now = @zone.local(2026, 7, 22, 12, 0)
    end

    test "creates an all-day camp event and a start reminder" do
      text = "Меланія 1 серпня іде в Табір і аж до 8 включно"
      message = user_message(text)
      actions = [
        action(
          kind: "create_event",
          title: "Табір Меланії",
          all_day: true,
          evidence: [ text ]
        ),
        action(
          kind: "create_reminder",
          title: "Початок табору Меланії",
          trigger_at: "2026-07-31T18:00:00+02:00",
          evidence: [ text ]
        )
      ]

      results = executor(message, text).call(actions)

      assert_equal %w[created created], results.map(&:status), results.map(&:message).inspect
      event = @family.events.last
      assert event.all_day?
      assert_equal @zone.local(2026, 8, 1, 0, 0), event.start_time.in_time_zone(@zone)
      assert_equal @zone.local(2026, 8, 9, 0, 0), event.end_time.in_time_zone(@zone)
      assert_equal @zone.local(2026, 7, 31, 18, 0), @family.reminders.last.trigger_at.in_time_zone(@zone)
    end

    test "creates a vacation as a future event without semantic knowledge" do
      text = "я маю відпустку робочу з 10 серпня по 24 включно серпня"
      message = user_message(text)

      executor(message, text).call([
        action(kind: "create_event", title: "Робоча відпустка", all_day: true, evidence: [ text ])
      ])

      event = @family.events.last
      assert_equal @zone.local(2026, 8, 10, 0, 0), event.start_time.in_time_zone(@zone)
      assert_equal @zone.local(2026, 8, 25, 0, 0), event.end_time.in_time_zone(@zone)
      assert_empty @family.family_knowledge
    end

    test "accepts a one-word event title grounded in the user message" do
      text = "Створи подію Відпустка з 10 серпня по 24 серпня"
      message = user_message(text)

      result = executor(message, text).call([
        action(kind: "create_event", title: "Відпустка", all_day: true, evidence: [ text ])
      ]).first

      assert_equal "created", result.status, result.message
      assert_equal "Відпустка", @family.events.last.title
    end

    test "reduces a generated reminder wrapper to words grounded in the user message" do
      text = "Я маю відпустку з 10 серпня"
      message = user_message(text)

      result = executor(message, text).call([
        action(
          kind: "create_reminder",
          title: "Нагадування про відпустку",
          trigger_at: "2026-08-09T18:00:00+02:00",
          evidence: [ text ]
        )
      ]).first

      assert_equal "created", result.status, result.message
      assert_equal "Відпустку", @family.reminders.last.title
    end

    test "combines credit and time follow-ups into a task and reminder" do
      credit_text = "до пятгниці мені потрібно проплатити кредит на 240 євро"
      time_text = "о 10 ранку"
      user_message(credit_text)
      current_message = user_message(time_text)
      source_text = [ credit_text, time_text ].join("\n")
      evidence = [ credit_text, time_text ]

      results = executor(current_message, source_text).call([
        action(kind: "create_task", title: "Проплатити кредит", evidence: evidence),
        action(
          kind: "create_reminder",
          title: "Проплатити кредит",
          trigger_at: "2026-07-24T10:00:00+02:00",
          evidence: evidence
        )
      ])

      assert_equal %w[created created], results.map(&:status), results.map(&:message).inspect
      assert_equal @zone.local(2026, 7, 24, 18, 0), @family.tasks.last.due_at.in_time_zone(@zone)
      assert_equal @zone.local(2026, 7, 24, 10, 0), @family.reminders.last.trigger_at.in_time_zone(@zone)
    end

    test "handles a mixed reminder and task turn without creating a meta task" do
      text = "створи нагадування про завтра садік, треба купити блокнот Гордій"
      message = user_message(text)
      actions = [
        action(kind: "create_reminder", title: "Садік завтра", evidence: [ text ]),
        action(kind: "create_task", title: "Купити блокнот Гордію", evidence: [ text ])
      ]

      executor_instance = executor(message, text)
      first_results = executor_instance.call(actions)
      second_results = executor_instance.call(actions)

      assert_equal %w[created created], first_results.map(&:status)
      assert_equal %w[already_completed already_completed], second_results.map(&:status)
      assert_equal 1, @family.tasks.count
      assert_equal 1, @family.reminders.count
      assert_equal 2, @family.ai_effects.count
      assert @family.ai_effects.none? { |effect| effect.details.present? }
      assert_not_equal "Створити нагадування", @family.tasks.last.title
    end

    test "updates only the clarified reminder time" do
      task = @family.tasks.create!(title: "Проплатити кредит", status: "pending", priority: 5, due_at: @zone.local(2026, 7, 24, 18))
      reminder = @family.reminders.create!(title: "Проплатити кредит", status: "pending", channel: "email", trigger_at: @zone.local(2026, 7, 24, 9))
      text = "о 10 ранку"
      message = user_message(text)

      result = executor(message, text).call([
        action(
          kind: "update_reminder",
          record_id: reminder.id,
          title: reminder.title,
          trigger_at: "2026-07-24T10:00:00+02:00",
          channel: "app",
          evidence: [ text ],
          changed_fields: [ "trigger_at" ]
        )
      ]).first

      assert_equal "updated", result.status
      assert_equal @zone.local(2026, 7, 24, 10), reminder.reload.trigger_at.in_time_zone(@zone)
      assert_equal "email", reminder.channel
      assert_equal 5, task.reload.priority
    end

    test "updates an event end without moving its start" do
      event = @family.events.create!(
        title: "Табір Меланії",
        source: "ai_chat",
        all_day: true,
        start_time: @zone.local(2026, 8, 1),
        end_time: @zone.local(2026, 8, 9)
      )
      text = "табір буде до 10 серпня включно"
      message = user_message(text)

      result = executor(message, text).call([
        action(
          kind: "update_event",
          record_id: event.id,
          title: event.title,
          end_at: "2026-08-11T00:00:00+02:00",
          all_day: true,
          evidence: [ text ],
          changed_fields: [ "end_at" ]
        )
      ]).first

      assert_equal "updated", result.status
      assert_equal @zone.local(2026, 8, 1), event.reload.start_time.in_time_zone(@zone)
      assert_equal @zone.local(2026, 8, 11), event.end_time.in_time_zone(@zone)
      assert event.all_day?
    end

    private

    def user_message(content)
      @family.ai_interactions.create!(role: "user", content: content, user: users(:one), model: "human")
    end

    def executor(message, source_text)
      ToolExecutor.new(family: @family, user_message: message, source_user_text: source_text, now: @now)
    end

    def action(overrides = {})
      {
        "kind" => "create_task",
        "record_id" => 0,
        "title" => "",
        "description" => "",
        "assignee_name" => "",
        "priority" => 3,
        "due_at" => "",
        "trigger_at" => "",
        "channel" => "app",
        "start_at" => "",
        "end_at" => "",
        "all_day" => false,
        "location" => "",
        "evidence" => [],
        "changed_fields" => []
      }.merge(overrides.stringify_keys)
    end
  end
end
