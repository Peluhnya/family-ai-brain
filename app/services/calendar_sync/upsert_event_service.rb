module CalendarSync
  class UpsertEventService
    def initialize(family:, payload:)
      @family = family
      @payload = payload
    end

    def call
      event = locate_event
      if @payload[:deleted]
        event.destroy! if event.persisted?
        return event
      end

      event.assign_attributes(
        title: @payload.fetch(:title),
        start_time: @payload.fetch(:start_time),
        end_time: @payload[:end_time],
        location: @payload[:location],
        external_id: @payload[:external_id],
        source: @payload[:source],
        source_key: @payload[:source_key]
      )
      event.save!
      event
    end

    private

    def locate_event
      if @payload[:sync_fingerprint].present?
        @family.events.find_or_initialize_by(sync_fingerprint: @payload[:sync_fingerprint])
      else
        @family.events.new
      end
    end
  end
end
