require "rexml/document"

module CalendarSync
  class AppleCaldavClient
    DEFAULT_URL = "https://caldav.icloud.com/".freeze

    def initialize(connection:)
      @connection = connection
    end

    def calendars
      home_url = discover_calendar_home
      document = propfind(home_url, calendar_properties, depth: 1)
      multistatus_responses(document).filter_map do |response|
        resource_type = property(response, "resourcetype")
        next unless resource_type && REXML::XPath.first(resource_type, ".//*[local-name()='calendar']")

        href = absolute_url(home_url, element_text(response, "href"))
        { id: href, summary: element_text(property(response, "displayname")).presence || href, color: element_text(property(response, "calendar-color")) }
      end
    end

    def calendar_data(calendar_url)
      body = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
          <d:prop><d:getetag/><c:calendar-data/></d:prop>
          <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT"/></c:comp-filter></c:filter>
        </c:calendar-query>
      XML
      document = request_xml(:report, calendar_url, body:, depth: 1)
      multistatus_responses(document).filter_map do |response|
        data = element_text(property(response, "calendar-data"))
        data if data.present?
      end
    end

    private

    def discover_calendar_home
      principal_document = propfind(DEFAULT_URL, "<d:current-user-principal/>", depth: 0)
      principal_href = element_text(property(multistatus_responses(principal_document).first, "current-user-principal"), "href")
      raise "Apple Calendar did not return a CalDAV principal." if principal_href.blank?

      principal_url = absolute_url(DEFAULT_URL, principal_href)
      home_document = propfind(principal_url, "<c:calendar-home-set/>", depth: 0)
      home_href = element_text(property(multistatus_responses(home_document).first, "calendar-home-set"), "href")
      raise "Apple Calendar did not return a calendar home." if home_href.blank?

      absolute_url(principal_url, home_href)
    end

    def calendar_properties
      '<d:displayname/><d:resourcetype/><c:calendar-description/><a:calendar-color xmlns:a="http://apple.com/ns/ical/"/>'
    end

    def propfind(url, properties, depth:)
      body = %(<?xml version="1.0" encoding="UTF-8"?><d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop>#{properties}</d:prop></d:propfind>)
      request_xml(:propfind, url, body:, depth:)
    end

    def request_xml(method, url, body:, depth:, redirects: 0)
      raise "Too many redirects while connecting to Apple Calendar." if redirects > 5

      uri = URI(url)
      request = if method == :report
        Net::HTTPGenericRequest.new("REPORT", true, true, uri.request_uri)
      else
        Net::HTTP::Propfind.new(uri)
      end
      request.basic_auth(username, password)
      request["Depth"] = depth.to_s
      request["Content-Type"] = "application/xml; charset=utf-8"
      request.body = body
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
      return request_xml(method, absolute_url(url, response["location"]), body:, depth:, redirects: redirects + 1) if response.is_a?(Net::HTTPRedirection)
      unless response.code.to_i.between?(200, 299)
        message = response.code.to_i == 401 ? "Apple Calendar rejected the Apple ID or app-specific password." : "Apple Calendar CalDAV request failed (HTTP #{response.code})."
        raise message
      end

      REXML::Document.new(response.body)
    rescue REXML::ParseException
      raise "Apple Calendar returned an invalid CalDAV response."
    end

    def username
      @connection.settings["apple_id"].to_s.strip.presence || raise("Apple ID is missing.")
    end

    def password
      @connection.access_token.to_s.presence || raise("Apple app-specific password is missing.")
    end

    def multistatus_responses(document)
      REXML::XPath.match(document, "//*[local-name()='response']")
    end

    def property(response, name)
      return if response.nil?
      REXML::XPath.first(response, ".//*[local-name()='prop']/*[local-name()='#{name}']")
    end

    def element_text(element, child_name = nil)
      return if element.nil?
      target = child_name ? REXML::XPath.first(element, ".//*[local-name()='#{child_name}']") : element
      target&.text.to_s.strip.presence
    end

    def absolute_url(base, href)
      URI.join(base, href.to_s).to_s
    end
  end
end
