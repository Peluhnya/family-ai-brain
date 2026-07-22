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
    end

    test "stores an explicitly stated durable preference" do
      text = "Наша сімʼя любить ходити в гори"
      client = FakeStructuredLlmClient.new(
        "facts" => [
          {
            "key" => "family_likes_mountains",
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
            "event_type" => "сімейна подорож",
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
      assert_equal "сімейна подорож", @family.life_logs.last.event_type
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
  end
end
