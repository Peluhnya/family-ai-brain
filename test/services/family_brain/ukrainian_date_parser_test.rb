require "test_helper"

module FamilyBrain
  class UkrainianDateParserTest < ActiveSupport::TestCase
    setup do
      @zone = ActiveSupport::TimeZone["Europe/Berlin"]
      @now = @zone.local(2026, 7, 22, 12, 0)
      @parser = UkrainianDateParser.new(reference_time: @now, timezone: "Europe/Berlin")
    end

    test "parses Ukrainian named month ranges with inclusive end" do
      start_at, end_at = @parser.parse_range("я маю відпустку з 10 серпня по 24 включно серпня")

      assert_equal @zone.local(2026, 8, 10, 0, 0), start_at
      assert_equal @zone.local(2026, 8, 25, 0, 0), end_at
    end

    test "inherits the month for a shortened camp range" do
      start_at, end_at = @parser.parse_range("Меланія 1 серпня іде в табір аж до 8 включно")

      assert_equal @zone.local(2026, 8, 1, 0, 0), start_at
      assert_equal @zone.local(2026, 8, 9, 0, 0), end_at
    end

    test "parses weekday typos apostrophes and an explicit Ukrainian clock" do
      typo_time = @parser.parse_datetime("до пятгниці о 10 ранку", default_hour: 18)
      apostrophe_time = @parser.parse_datetime("в пʼятницю о 10:30", default_hour: 18)

      assert_equal @zone.local(2026, 7, 24, 10, 0), typo_time
      assert_equal @zone.local(2026, 7, 24, 10, 30), apostrophe_time
    end

    test "applies the requested default hour to an ISO date" do
      assert_equal @zone.local(2026, 7, 24, 18, 0), @parser.parse_datetime("2026-07-24", default_hour: 18)
    end
  end
end
