require "test_helper"

module FamilyBrain
  class MemorySyncTest < ActiveSupport::TestCase
    NullEmbeddingService = Class.new do
      def self.embed(*)
        nil
      end
    end

    setup do
      @family = families(:one)
      @family.update!(timezone: "Europe/Berlin")
      @zone = ActiveSupport::TimeZone["Europe/Berlin"]
      @now = @zone.local(2026, 7, 22, 12)
    end

    test "does not store a future vacation as semantic knowledge" do
      text = "Я маю робочу відпустку з 10 серпня по 24 серпня"
      client = FakeStructuredLlmClient.new(
        "facts" => [
          {
            "key" => "work_vacation",
            "value" => "Робоча відпустка триватиме 10-24 серпня.",
            "evidence" => text,
            "confidence" => 0.95,
            "source" => "chat:auto"
          }
        ]
      )

      result = KnowledgeSyncService.new(family: @family, text: text, source: "chat:auto", now: @now, llm_client: client).call

      assert_empty result
      assert_empty @family.family_knowledge
      assert_equal 1, client.prompts.size
    end

    test "stores an explicitly stated durable preference" do
      text = "Наша сімʼя любить ходити в гори"
      client = FakeStructuredLlmClient.new(
        "facts" => [
          {
            "key" => "family_likes_mountains",
            "durable" => true,
            "value" => "Сімʼя любить ходити в гори.",
            "evidence" => text,
            "confidence" => 0.95,
            "source" => "chat:auto"
          }
        ]
      )

      result = KnowledgeSyncService.new(
        family: @family,
        text: text,
        source: "chat:auto",
        now: @now,
        llm_client: client,
        embedding_service: NullEmbeddingService
      ).call
      assert_equal 1, result.size
      assert_equal "family_likes_mountains", @family.family_knowledge.last.key
      assert_equal text, @family.family_knowledge.last.value
    end

    test "does not store a completed dated trip as semantic knowledge" do
      text = "Ми повернулися з гір 20 липня"
      client = FakeStructuredLlmClient.new(
        "facts" => [
          {
            "key" => "mountain_trip_2026",
            "value" => "Сім’я була в горах 20 липня.",
            "evidence" => text,
            "confidence" => 0.9,
            "source" => "chat:auto"
          }
        ]
      )

      result = KnowledgeSyncService.new(
        family: @family,
        text: text,
        source: "chat:auto",
        now: @now,
        llm_client: client,
        embedding_service: NullEmbeddingService
      ).call

      assert_empty result
      assert_empty @family.family_knowledge
    end

    test "stores a completed meaningful experience as episodic memory" do
      text = "Ми повернулися з відпустки в горах і вперше всі разом піднялися на вершину"
      client = FakeStructuredLlmClient.new(
        "life_logs" => [
          {
            "event_type" => "trip",
            "occurred" => true,
            "summary" => "Сім’я разом піднялася на гірську вершину",
            "evidence" => text,
            "importance" => 0.9,
            "happened_at" => "2026-07-21T18:00:00+02:00"
          }
        ]
      )

      result = LifeLogSyncService.new(
        family: @family,
        text: text,
        now: @now,
        llm_client: client,
        embedding_service: NullEmbeddingService
      ).call
      assert_equal 1, result.size
      assert_equal "trip", @family.life_logs.last.event_type
      assert_equal text, @family.life_logs.last.summary
    end

    test "rejects a future experience from episodic memory" do
      text = "Завтра ми поїдемо в гори"
      client = FakeStructuredLlmClient.new(
        "life_logs" => [
          {
            "event_type" => "подорож",
            "summary" => "Сім’я поїхала в гори",
            "evidence" => text,
            "importance" => 0.7,
            "happened_at" => "2026-07-23T09:00:00+02:00"
          }
        ]
      )

      result = LifeLogSyncService.new(family: @family, text: text, now: @now, llm_client: client).call

      assert_empty result
      assert_empty @family.life_logs
    end

    test "rejects a future English vacation from semantic knowledge" do
      text = "We have a family holiday from 10 to 24 August"
      client = FakeStructuredLlmClient.new(
        "facts" => [
          {
            "key" => "family_holiday",
            "value" => "The family holiday runs from 10 to 24 August.",
            "evidence" => text,
            "confidence" => 0.9,
            "source" => "chat:auto"
          }
        ]
      )

      result = KnowledgeSyncService.new(
        family: @family,
        text: text,
        source: "chat:auto",
        now: @now,
        llm_client: client,
        embedding_service: NullEmbeddingService
      ).call

      assert_empty result
      assert_equal 1, client.prompts.size
    end

    test "rejects a future German experience from episodic memory" do
      text = "Morgen werden wir in die Berge fahren"
      client = FakeStructuredLlmClient.new(
        "life_logs" => [
          {
            "event_type" => "Familienausflug",
            "summary" => "Die Familie fuhr gemeinsam in die Berge",
            "evidence" => text,
            "importance" => 0.7,
            "happened_at" => "2026-07-23T09:00:00+02:00"
          }
        ]
      )

      result = LifeLogSyncService.new(family: @family, text: text, now: @now, llm_client: client).call

      assert_empty result
      assert_equal 1, client.prompts.size
    end

    test "does not store a future vacation with no plans as episodic memory" do
      text = "я маю відпустку з 10 червня по 24 включно. правда пока нічого не планував на неї"
      client = FakeStructuredLlmClient.new(
        "life_logs" => [
          {
            "event_type" => "Відпустка",
            "summary" => "Не планував на неї",
            "evidence" => "правда пока нічого не планував на неї",
            "importance" => 0.2,
            "happened_at" => @now.iso8601
          }
        ]
      )

      result = LifeLogSyncService.new(family: @family, text: text, now: @now, llm_client: client).call

      assert_empty result
      assert_empty @family.life_logs
      assert_equal 1, client.prompts.size
    end

    test "stores the exact evidence instead of a hallucinated episodic summary" do
      text = "Ми повернулися з відпустки в горах"
      client = FakeStructuredLlmClient.new(
        "life_logs" => [
          {
            "event_type" => "trip",
            "occurred" => true,
            "summary" => "Виграли вітрильник у Греції",
            "evidence" => text,
            "importance" => 0.8,
            "happened_at" => "2026-07-21T18:00:00+02:00"
          }
        ]
      )

      result = LifeLogSyncService.new(family: @family, text: text, now: @now, llm_client: client).call

      assert_equal 1, result.size
      assert_equal text, @family.life_logs.last.summary
      assert_not_equal "Виграли вітрильник у Греції", @family.life_logs.last.summary
      assert_equal 1, client.prompts.size
    end

    test "stores the exact evidence instead of an invented opposite preference" do
      text = "Наша сім’я любить нагадування"
      client = FakeStructuredLlmClient.new(
        "facts" => [
          {
            "key" => "user_preferences",
            "durable" => true,
            "value" => "Сім’я не любить нагадування.",
            "evidence" => text,
            "confidence" => 0.9,
            "source" => "chat:auto"
          }
        ]
      )

      result = KnowledgeSyncService.new(
        family: @family,
        text: text,
        source: "chat:auto",
        now: @now,
        llm_client: client
      ).call

      assert_equal 1, result.size
      assert_equal text, @family.family_knowledge.last.value
      assert_not_equal "Сім’я не любить нагадування.", @family.family_knowledge.last.value
      assert_equal 1, client.prompts.size
    end

    test "supports completed English and German memories conservatively" do
      english_text = "We returned from our holiday and visited the mountains together"
      english_client = FakeStructuredLlmClient.new(
        "life_logs" => [
          {
            "event_type" => "trip",
            "occurred" => true,
            "summary" => "We visited the mountains together",
            "evidence" => english_text,
            "importance" => 0.8,
            "happened_at" => "2026-07-21T18:00:00+02:00"
          }
        ]
      )
      german_text = "Wir sind aus dem Urlaub zurückgekehrt und haben gemeinsam die Berge besucht"
      german_client = FakeStructuredLlmClient.new(
        "life_logs" => [
          {
            "event_type" => "trip",
            "occurred" => true,
            "summary" => "Wir haben gemeinsam die Berge besucht",
            "evidence" => german_text,
            "importance" => 0.8,
            "happened_at" => "2026-07-20T18:00:00+02:00"
          }
        ]
      )

      english = LifeLogSyncService.new(
        family: @family, text: english_text, now: @now, llm_client: english_client, embedding_service: NullEmbeddingService
      ).call
      german = LifeLogSyncService.new(
        family: @family, text: german_text, now: @now, llm_client: german_client, embedding_service: NullEmbeddingService
      ).call

      assert_equal 1, english.size
      assert_equal 1, german.size
      assert_equal english_text, english.first.summary
      assert_equal german_text, german.first.summary
    end
  end
end
