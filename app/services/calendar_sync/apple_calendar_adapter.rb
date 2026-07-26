module CalendarSync
  class AppleCalendarAdapter
    def initialize(connection:)
      @connection = connection
    end

    def fetch_events
      raise "Apple Calendar connection is missing credentials." unless @connection.ready_for_remote_sync?

      client = AppleCaldavClient.new(connection: @connection)
      selected_calendar_ids.flat_map do |calendar_id|
        client.calendar_data(calendar_id).flat_map { |icalendar| parse_events(icalendar, calendar_id:) }
      end
    end

    private

    def selected_calendar_ids
      ids = Array(@connection.settings["apple_calendar_ids"]).compact_blank.uniq
      raise "Choose at least one Apple calendar to sync." if ids.empty?

      ids
    end

    def parse_events(icalendar, calendar_id:)
      unfolded = icalendar.gsub(/\r?\n[ \t]/, "")
      unfolded.scan(/BEGIN:VEVENT\r?\n(.*?)\r?\nEND:VEVENT/m).filter_map do |match|
        fields = match.first.lines.each_with_object({}) do |line, values|
          key, value = line.strip.split(":", 2)
          next if value.blank?
          values[key] = value
        end
        normalize_event(fields, calendar_id:) if fields.keys.any? { |key| key.start_with?("DTSTART") }
      end
    end

    def normalize_event(fields, calendar_id:)
      start_key = fields.keys.find { |key| key.start_with?("DTSTART") }
      end_key = fields.keys.find { |key| key.start_with?("DTEND") }
      uid = fields["UID"].presence || Digest::SHA256.hexdigest(fields.to_s)
      recurrence_id = fields.find { |key, _| key.start_with?("RECURRENCE-ID") }&.last
      {
        external_id: "#{Digest::SHA256.hexdigest(calendar_id)}:#{uid}:#{recurrence_id}",
        external_calendar_id: calendar_id,
        external_event_id: [ uid, recurrence_id ].compact.join(":"),
        title: unescape(fields["SUMMARY"]).presence || "Apple Calendar event",
        start_time: parse_time(fields[start_key], all_day: date_value?(start_key)),
        end_time: parse_time(fields[end_key], all_day: date_value?(end_key)),
        all_day: date_value?(start_key),
        location: unescape(fields["LOCATION"]),
        deleted: fields["STATUS"] == "CANCELLED"
      }
    end

    def date_value?(key)
      key.to_s.include?("VALUE=DATE")
    end

    def parse_time(value, all_day:)
      return if value.blank?
      return Time.zone.parse("#{Date.strptime(value, '%Y%m%d')} 00:00:00") if all_day

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end

    def unescape(value)
      value.to_s.gsub("\\n", "\n").gsub("\\,", ",").gsub("\\;", ";").gsub("\\\\", "\\").presence
    end
  end
end
