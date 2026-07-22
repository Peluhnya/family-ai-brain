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

    test "marks a uniquely resolved task as done" do
      task = @family.tasks.create!(title: "Купити молоко", status: "pending", priority: 3)
      text = "Познач задачу купити молоко виконаною"
      message = user_message(text)

      result = executor(message, text).call([
        action(
          kind: "update_task",
          record_id: task.id,
          title: task.title,
          status: "done",
          evidence: [ text ],
          changed_fields: [ "status" ]
        )
      ]).first

      assert_equal "updated", result.status
      assert_equal "done", task.reload.status
    end

    test "stores exact durable knowledge without paraphrasing" do
      text = "Наша сімʼя любить ходити в гори"
      message = user_message(text)

      result = executor(message, text).call([
        action(
          kind: "create_knowledge",
          key: "family_likes_mountains",
          value: text,
          source: "chat:planner",
          confidence: 0.95,
          evidence: [ text ]
        )
      ]).first

      assert_equal "created", result.status, result.message
      assert_equal text, @family.family_knowledge.last.value
    end

    test "does not overwrite conflicting knowledge through create" do
      existing = @family.family_knowledge.create!(
        key: "school_start_time",
        value: "Школа починається о восьмій",
        source: "manual",
        confidence: 1.0
      )
      text = "Школа починається о девʼятій"
      message = user_message(text)

      result = executor(message, text).call([
        action(
          kind: "create_knowledge",
          key: existing.key,
          value: text,
          source: "chat:planner",
          confidence: 0.9,
          evidence: [ text ]
        )
      ]).first

      assert_equal "failed", result.status
      assert_equal "Школа починається о восьмій", existing.reload.value
    end

    test "stores a completed meaningful experience as life history" do
      text = "Учора Меланія вперше виступила на концерті"
      message = user_message(text)

      result = executor(message, text).call([
        action(
          kind: "create_life_log",
          event_type: "milestone",
          summary: text,
          raw_text: text,
          importance: 0.9,
          happened_at: "2026-07-21T18:00:00+02:00",
          evidence: [ text ]
        )
      ]).first

      assert_equal "created", result.status, result.message
      assert_equal text, @family.life_logs.last.summary
      assert_equal "milestone", @family.life_logs.last.event_type
    end

    test "creates a document only from exact conversation content" do
      title_text = "Збережи документ Сімейні правила"
      content_text = "Завжди перевіряти календар перед плануванням сімейної поїздки"
      message = user_message(title_text)
      source_text = [ title_text, content_text ].join("\n")

      result = executor(message, source_text).call([
        action(
          kind: "create_document",
          title: "Сімейні правила",
          content: content_text,
          evidence: [ title_text, content_text ]
        )
      ]).first

      assert_equal "created", result.status, result.message
      assert_equal content_text, @family.documents.last.content
    end

    test "creates a confirmed structured automation rule" do
      text = "Створи щоденну автоматизацію о 08:00: перевірити сімейний календар"
      message = user_message(text)

      result = executor(message, text).call([
        action(
          kind: "create_automation_rule",
          title: "Щоденна автоматизація календаря",
          active: true,
          automation_trigger_type: "schedule_daily",
          automation_trigger_time: "08:00",
          automation_action_type: "create_task",
          automation_action_title: "Перевірити сімейний календар",
          automation_offset_days: 0,
          evidence: [ text ]
        )
      ]).first

      assert_equal "created", result.status, result.message
      rule = @family.automation_rules.last
      assert_equal "schedule_daily", rule.trigger_type
      assert_equal({ "time" => "08:00" }, rule.trigger_config)
      assert_equal "create_task", rule.action_type
      assert_equal "Перевірити сімейний календар", rule.action_config["title"]
      assert rule.active?
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
        "status" => "",
        "due_at" => "",
        "trigger_at" => "",
        "channel" => "app",
        "start_at" => "",
        "end_at" => "",
        "all_day" => false,
        "location" => "",
        "key" => "",
        "value" => "",
        "source" => "",
        "confidence" => 0.7,
        "event_type" => "",
        "summary" => "",
        "raw_text" => "",
        "importance" => 0.5,
        "happened_at" => "",
        "content" => "",
        "active" => false,
        "automation_trigger_type" => "",
        "automation_trigger_time" => "",
        "automation_trigger_weekday" => "",
        "automation_trigger_day" => 0,
        "automation_trigger_keyword" => "",
        "automation_match_mode" => "",
        "automation_action_type" => "",
        "automation_action_title" => "",
        "automation_action_content" => "",
        "automation_offset_days" => 0,
        "automation_duration_hours" => 1,
        "automation_channel" => "app",
        "evidence" => [],
        "changed_fields" => []
      }.merge(overrides.stringify_keys)
    end
  end
end
