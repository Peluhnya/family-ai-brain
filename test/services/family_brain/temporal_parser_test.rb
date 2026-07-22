require "test_helper"

module FamilyBrain
  class TemporalParserTest < ActiveSupport::TestCase
    setup do
      @zone = ActiveSupport::TimeZone["Europe/Berlin"]
      @now = @zone.local(2026, 7, 22, 12)
    end

    test "parses equivalent all-day ranges in Ukrainian German and English" do
      expectations = {
        "uk-UA" => "Маємо відпустку з 1 серпня по 8 серпня включно",
        "de-DE" => "Wir haben Urlaub vom 1. bis 8. August",
        "en-GB" => "We have a holiday from 1 to 8 August",
        "en-US" => "We have a vacation from August 1 through August 8 inclusive"
      }

      expectations.each do |locale, text|
        start_at, end_at = parser(locale).parse_range(text)

        assert_equal @zone.local(2026, 8, 1), start_at, locale
        assert_equal @zone.local(2026, 8, 9), end_at, locale
      end
    end

    test "parses localized weekdays and clocks" do
      assert_equal @zone.local(2026, 7, 24, 10), parser("uk-UA").parse_datetime("у пʼятницю о 10 ранку")
      assert_equal @zone.local(2026, 7, 24, 10), parser("de-DE").parse_datetime("am Freitag um 10 Uhr")
      assert_equal @zone.local(2026, 7, 24, 22, 30), parser("en-GB").parse_datetime("on Friday at 10:30 pm")
    end

    test "uses regional order for ambiguous numeric dates" do
      assert_equal @zone.local(2026, 8, 3, 9), parser("en-GB").parse_datetime("03/08/2026")
      assert_equal @zone.local(2026, 3, 8, 9), parser("en-US").parse_datetime("03/08/2026")
    end

    test "detects the message language before using the family fallback" do
      assert_equal "uk-UA", LanguageResolver.resolve(text: "нагадай завтра", fallback: "de-DE")
      assert_equal "de-DE", LanguageResolver.resolve(text: "Erinnere mich morgen", fallback: "uk-UA")
      assert_equal "en-US", LanguageResolver.resolve(text: "Remind me tomorrow", fallback: "en-US")
      assert_equal "en-GB", LanguageResolver.resolve(text: "10:30", fallback: "en-GB")
      assert_equal "en-GB", LanguageResolver.resolve(text: "10:30", context: "Remind me tomorrow", fallback: "uk-UA")
      assert_equal "de-DE", LanguageResolver.resolve(text: "10:30", context: "Erinnere mich morgen", fallback: "uk-UA")
    end

    private

    def parser(locale)
      TemporalParser.new(reference_time: @now, timezone: "Europe/Berlin", locale: locale)
    end
  end
end
