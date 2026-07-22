module FamilyBrain
  class UkrainianDateParser
    MONTHS = {
      "січня" => 1,
      "лютого" => 2,
      "березня" => 3,
      "квітня" => 4,
      "травня" => 5,
      "червня" => 6,
      "липня" => 7,
      "серпня" => 8,
      "вересня" => 9,
      "жовтня" => 10,
      "листопада" => 11,
      "грудня" => 12
    }.freeze
    WEEKDAYS = {
      "неділ" => 0,
      "понеділ" => 1,
      "вівтор" => 2,
      "серед" => 3,
      "четвер" => 4,
      "пятниц" => 5,
      "субот" => 6
    }.freeze
    MONTH_PATTERN = MONTHS.keys.join("|").freeze

    def initialize(reference_time: Time.current, timezone: nil)
      @zone = ActiveSupport::TimeZone[timezone.presence] || Time.zone
      @reference_time = reference_time.in_time_zone(@zone)
    end

    def parse_datetime(value, default_hour: 9, honor_clock: true)
      text = value.to_s.strip
      return if text.blank?

      iso_time = parse_iso8601(text, default_hour: default_hour)
      return iso_time if iso_time

      normalized = normalize(text)
      date = extract_date(normalized)
      return unless date

      hour, minute = honor_clock ? extract_clock(normalized, default_hour: default_hour) : [ default_hour, 0 ]
      @zone.local(date.year, date.month, date.day, hour, minute)
    end

    # For all-day calendar events the returned end is exclusive, matching
    # external calendar APIs: 1-8 August becomes [Aug 1, Aug 9).
    def parse_range(value)
      text = value.to_s.strip
      return if text.blank?

      normalized = normalize(text)
      range = extract_named_month_range(normalized)
      return range if range

      start_at = parse_datetime(text, default_hour: 0)
      return unless start_at

      [ start_at.beginning_of_day, start_at.beginning_of_day + 1.day ]
    end

    private

    def parse_iso8601(text, default_hour:)
      if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        date = Date.iso8601(text)
        return @zone.local(date.year, date.month, date.day, default_hour)
      end
      return unless text.match?(/\A\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2})/)

      Time.iso8601(text).in_time_zone(@zone)
    rescue ArgumentError, TypeError
      begin
        @zone.parse(text)
      rescue ArgumentError, TypeError
        nil
      end
    end

    def normalize(text)
      text.downcase
        .tr("’ʼ`'", "")
        .gsub(/пятгниц/u, "пятниц")
        .gsub(/\s+/, " ")
        .strip
    end

    def extract_date(text)
      return @reference_time.to_date if text.match?(/\bсьогодні\b/)
      return @reference_time.to_date + 1.day if text.match?(/\bзавтра\b/)
      return @reference_time.to_date + 2.days if text.match?(/\bпіслязавтра\b/)

      if (match = text.match(/\b(?<day>\d{1,2})[.\/-](?<month>\d{1,2})(?:[.\/-](?<year>\d{2,4}))?\b/))
        return future_date(day: match[:day], month: match[:month], year: match[:year])
      end

      if (match = text.match(/\b(?<day>\d{1,2})\s+(?<month>#{MONTH_PATTERN})(?:\s+(?<year>\d{4}))?\b/u))
        return future_date(day: match[:day], month: MONTHS.fetch(match[:month]), year: match[:year])
      end

      weekday = WEEKDAYS.find { |stem, _| text.include?(stem) }&.last
      return unless weekday

      days_ahead = (weekday - @reference_time.wday) % 7
      @reference_time.to_date + days_ahead.days
    rescue Date::Error
      nil
    end

    def future_date(day:, month:, year: nil)
      numeric_year = normalize_year(year)
      date = Date.new(numeric_year, month.to_i, day.to_i)
      date = date.next_year if year.blank? && date < @reference_time.to_date
      date
    end

    def normalize_year(year)
      return @reference_time.year if year.blank?

      numeric = year.to_i
      numeric < 100 ? 2000 + numeric : numeric
    end

    def extract_clock(text, default_hour:)
      match = text.match(/\b(?<hour>\d{1,2}):(?<minute>\d{2})\b/u) ||
        text.match(/\bо\s*(?<hour>\d{1,2})(?::(?<minute>\d{2}))?\b/u) ||
        text.match(/\b(?<hour>\d{1,2})(?::(?<minute>\d{2}))?\s*(?<period>ранку|дня|вечора|ночі)\b/u)
      return [ default_hour, 0 ] unless match

      hour = match[:hour].to_i
      minute = match[:minute].to_i
      period = match.names.include?("period") ? match[:period] : nil
      hour += 12 if %w[дня вечора].include?(period) && hour < 12
      hour = 0 if period == "ночі" && hour == 12
      return [ default_hour, 0 ] unless hour.between?(0, 23) && minute.between?(0, 59)

      [ hour, minute ]
    end

    def extract_named_month_range(text)
      match = text.match(
        /\b(?<start_day>\d{1,2})\s+(?<month>#{MONTH_PATTERN})(?:\s+(?<year>\d{4}))?.*?(?:\bдо\b|\bпо\b|[-–—])\s*(?<end_day>\d{1,2})(?:\s+включно)?(?:\s+(?<end_month>#{MONTH_PATTERN}))?(?:\s+(?<end_year>\d{4}))?/u
      )
      return unless match

      start_date = future_date(day: match[:start_day], month: MONTHS.fetch(match[:month]), year: match[:year])
      end_month = MONTHS.fetch(match[:end_month].presence || match[:month])
      end_date = future_date(day: match[:end_day], month: end_month, year: match[:end_year].presence || match[:year])
      end_date = end_date.next_year if end_date < start_date

      [
        @zone.local(start_date.year, start_date.month, start_date.day).beginning_of_day,
        @zone.local(end_date.year, end_date.month, end_date.day).beginning_of_day + 1.day
      ]
    rescue Date::Error
      nil
    end
  end
end
