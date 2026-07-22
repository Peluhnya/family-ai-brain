module FamilyBrain
  class TemporalParser
    DAY_SUFFIX = /(?:\.|st|nd|rd|th)?/i

    def initialize(reference_time: Time.current, timezone: nil, locale: nil)
      @zone = (ActiveSupport::TimeZone[timezone] if timezone.present?) || Time.zone
      @reference_time = reference_time.in_time_zone(@zone)
      @fallback_locale = FamilyBrain::LocaleCatalog.normalize(locale) || FamilyBrain::LocaleCatalog::DEFAULT_LOCALE
    end

    def parse_datetime(value, default_hour: 9, honor_clock: true)
      text = value.to_s.strip
      return if text.blank?

      iso_time = parse_iso8601(text, default_hour: default_hour)
      return iso_time if iso_time

      packs = packs_for(text)
      date = extract_date(text, packs)
      return unless date

      hour, minute = honor_clock ? extract_clock(text, packs, default_hour: default_hour) : [ default_hour, 0 ]
      @zone.local(date.year, date.month, date.day, hour, minute)
    end

    # All-day ranges use an exclusive end: August 1-8 becomes [Aug 1, Aug 9).
    def parse_range(value)
      text = value.to_s.strip
      return if text.blank?

      packs_for(text).each do |pack|
        range = extract_named_month_range(normalize(text, pack), pack)
        return range if range
      end

      start_at = parse_datetime(text, default_hour: 0)
      return unless start_at

      [ start_at.beginning_of_day, start_at.beginning_of_day + 1.day ]
    end

    def temporal_reference?(value)
      text = value.to_s.strip
      return false if text.blank?
      return true if text.match?(/\b\d{1,2}:\d{2}\b|\b\d{1,2}[.\/-]\d{1,2}(?:[.\/-]\d{2,4})?\b/)

      packs = packs_for(text)
      extract_date(text, packs).present? || clock_present?(text, packs)
    end

    private

    def packs_for(text)
      locale = FamilyBrain::LanguageResolver.resolve(text: text, fallback: @fallback_locale)
      FamilyBrain::LocaleCatalog.unique_language_packs(locale)
    end

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

    def normalize(text, pack)
      normalized = text.downcase.tr("’ʼ`'", "").gsub(/\s+/, " ").strip
      pack[:normalizations].each { |pattern, replacement| normalized = normalized.gsub(pattern, replacement) }
      normalized
    end

    def extract_date(text, packs)
      packs.each do |pack|
        normalized = normalize(text, pack)
        relative_date = extract_relative_date(normalized, pack)
        return relative_date if relative_date

        named_date = extract_named_date(normalized, pack)
        return named_date if named_date

        weekday_date = extract_weekday(normalized, pack)
        return weekday_date if weekday_date
      end

      extract_numeric_date(text, packs.first)
    end

    def extract_relative_date(text, pack)
      pack[:relative_days].each do |days, phrases|
        return @reference_time.to_date + days.days if phrases.any? { |phrase| phrase_present?(text, phrase) }
      end
      nil
    end

    def extract_named_date(text, pack)
      month_pattern = alternatives_pattern(pack[:months].keys)
      day_first = text.match(/\b(?<day>\d{1,2})#{DAY_SUFFIX}\s+(?<month>#{month_pattern})(?:\s+(?<year>\d{4}))?\b/iu)
      month_first = text.match(/\b(?<month>#{month_pattern})\s+(?<day>\d{1,2})#{DAY_SUFFIX}(?:[,]?\s+(?<year>\d{4}))?\b/iu)
      match = day_first || month_first
      return unless match

      future_date(day: match[:day], month: pack[:months].fetch(match[:month]), year: match[:year])
    rescue Date::Error
      nil
    end

    def extract_numeric_date(text, pack)
      match = normalize(text, pack).match(/\b(?<first>\d{1,2})[.\/-](?<second>\d{1,2})(?:[.\/-](?<year>\d{2,4}))?\b/)
      return unless match

      day, month = if pack[:date_order] == :month_day
        [ match[:second], match[:first] ]
      else
        [ match[:first], match[:second] ]
      end
      future_date(day: day, month: month, year: match[:year])
    rescue Date::Error
      nil
    end

    def extract_weekday(text, pack)
      weekday = pack[:weekdays].find { |stem, _| text.include?(stem) }&.last
      return unless weekday

      days_ahead = (weekday - @reference_time.wday) % 7
      @reference_time.to_date + days_ahead.days
    end

    def extract_clock(text, packs, default_hour:)
      packs.each do |pack|
        normalized = normalize(text, pack)
        named_time = pack[:named_times].find { |phrase, _| phrase_present?(normalized, phrase) }&.last
        return named_time if named_time

        period_match = clock_with_period_match(normalized, pack)
        return normalize_period_clock(period_match, pack) if period_match

        preposition_match = clock_with_marker_match(normalized, pack[:clock_prepositions])
        return valid_clock(preposition_match, default_hour) if preposition_match

        suffix_match = clock_with_marker_match(normalized, pack[:clock_suffixes], suffix: true)
        return valid_clock(suffix_match, default_hour) if suffix_match
      end

      match = text.match(/\b(?<hour>\d{1,2}):(?<minute>\d{2})\b/)
      valid_clock(match, default_hour)
    end

    def clock_present?(text, packs)
      sentinel = -1
      extract_clock(text, packs, default_hour: sentinel).first != sentinel
    end

    def clock_with_period_match(text, pack)
      return if pack[:periods].empty?

      periods = alternatives_pattern(pack[:periods].keys)
      text.match(/\b(?<hour>\d{1,2})(?::(?<minute>\d{2}))?\s*(?<period>#{periods})(?!\p{L})/iu)
    end

    def clock_with_marker_match(text, markers, suffix: false)
      return if markers.empty?

      marker_pattern = alternatives_pattern(markers)
      if suffix
        text.match(/\b(?<hour>\d{1,2})(?::(?<minute>\d{2}))?\s*(?:#{marker_pattern})\b/iu)
      else
        text.match(/\b(?:#{marker_pattern})\s*(?<hour>\d{1,2})(?::(?<minute>\d{2}))?/iu)
      end
    end

    def normalize_period_clock(match, pack)
      hour = match[:hour].to_i
      minute = match[:minute].to_i
      period = pack[:periods].fetch(match[:period])
      hour = 0 if period == :am && hour == 12
      hour += 12 if period == :pm && hour < 12
      hour = hour == 12 ? 0 : hour + 12 if period == :night && hour < 12
      valid_clock_values(hour, minute, 9)
    end

    def valid_clock(match, default_hour)
      return [ default_hour, 0 ] unless match

      valid_clock_values(match[:hour].to_i, match[:minute].to_i, default_hour)
    end

    def valid_clock_values(hour, minute, default_hour)
      return [ default_hour, 0 ] unless hour.between?(0, 23) && minute.between?(0, 59)

      [ hour, minute ]
    end

    def extract_named_month_range(text, pack)
      month_pattern = alternatives_pattern(pack[:months].keys)
      connector_pattern = range_connector_pattern(pack)
      inclusive_pattern = optional_inclusive_pattern(pack)

      match = text.match(
        /\b(?<start_day>\d{1,2})#{DAY_SUFFIX}\s+(?<start_month>#{month_pattern})(?:\s+(?<start_year>\d{4}))?.{0,80}?(?:#{connector_pattern})\s*(?<end_day>\d{1,2})#{DAY_SUFFIX}#{inclusive_pattern}(?:\s+(?<end_month>#{month_pattern}))?(?:\s+(?<end_year>\d{4}))?\b/iu
      )
      match ||= text.match(
        /\b(?<start_day>\d{1,2})#{DAY_SUFFIX}.{0,30}?(?:#{connector_pattern})\s*(?<end_day>\d{1,2})#{DAY_SUFFIX}#{inclusive_pattern}\s+(?<start_month>#{month_pattern})(?:\s+(?<end_year>\d{4}))?\b/iu
      )
      match ||= text.match(
        /\b(?<start_month>#{month_pattern})\s+(?<start_day>\d{1,2})#{DAY_SUFFIX}(?:[,]?\s+(?<start_year>\d{4}))?.{0,50}?(?:#{connector_pattern})\s*(?:(?<end_month>#{month_pattern})\s+)?(?<end_day>\d{1,2})#{DAY_SUFFIX}#{inclusive_pattern}(?:[,]?\s+(?<end_year>\d{4}))?\b/iu
      )
      return unless match

      build_range(match, pack)
    end

    def build_range(match, pack)
      start_month = pack[:months].fetch(match[:start_month])
      end_month_name = match.names.include?("end_month") ? match[:end_month].presence : nil
      end_month = pack[:months].fetch(end_month_name || match[:start_month])
      start_year = match.names.include?("start_year") ? match[:start_year] : nil
      end_year = match.names.include?("end_year") ? match[:end_year].presence : nil
      start_date = future_date(day: match[:start_day], month: start_month, year: start_year)
      end_date = future_date(day: match[:end_day], month: end_month, year: end_year || start_year)
      end_date = end_date.next_year if end_date < start_date

      [
        @zone.local(start_date.year, start_date.month, start_date.day).beginning_of_day,
        @zone.local(end_date.year, end_date.month, end_date.day).beginning_of_day + 1.day
      ]
    rescue Date::Error
      nil
    end

    def range_connector_pattern(pack)
      words = alternatives_pattern(pack[:range_connectors])
      "(?:#{words}|[-–—])"
    end

    def optional_inclusive_pattern(pack)
      return "" if pack[:inclusive_words].empty?

      "(?:\\s+(?:#{alternatives_pattern(pack[:inclusive_words])}))?"
    end

    def alternatives_pattern(values)
      values.sort_by { |value| -value.length }.map { |value| Regexp.escape(value) }.join("|")
    end

    def phrase_present?(text, phrase)
      text.match?(/(?<!\p{L})#{Regexp.escape(phrase)}(?!\p{L})/iu)
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
  end
end
