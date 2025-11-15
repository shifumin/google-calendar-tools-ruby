#!/usr/bin/env ruby
# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "date"
require "json"

# GoogleCalendarFetcher fetches events from Google Calendar for a specified date
class GoogleCalendarFetcher
  APPLICATION_NAME = "Google Calendar Fetcher"
  TOKEN_PATH = File.join(Dir.home, ".credentials", "calendar-fetcher-token.yaml")
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
    @calendar_ids = parse_calendar_ids

    validate_configuration
  end

  def fetch_events(date)
    time_min = DateTime.parse("#{date}T00:00:00+09:00").rfc3339
    time_max = DateTime.parse("#{date}T23:59:59+09:00").rfc3339

    calendars_data = @calendar_ids.map do |calendar_id|
      fetch_calendar_data(calendar_id, time_min, time_max)
    end

    display_events(calendars_data, date)
  end

  private

  def parse_calendar_ids
    # Support both GOOGLE_CALENDAR_IDS (comma-separated) and GOOGLE_CALENDAR_ID (single, for backward compatibility)
    if ENV["GOOGLE_CALENDAR_IDS"]
      ENV["GOOGLE_CALENDAR_IDS"].split(",").map(&:strip)
    elsif ENV["GOOGLE_CALENDAR_ID"]
      [ENV["GOOGLE_CALENDAR_ID"]]
    else
      []
    end
  end

  def authorize
    client_id = Google::Auth::ClientId.new(
      ENV.fetch("GOOGLE_CLIENT_ID", nil),
      ENV.fetch("GOOGLE_CLIENT_SECRET", nil)
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

    user_id = "default"
    credentials = authorizer.get_credentials(user_id)

    raise "No credentials found. Please run 'ruby setup_oauth.rb' first to authenticate." if credentials.nil?

    credentials
  end

  def validate_configuration
    raise "GOOGLE_CALENDAR_IDS or GOOGLE_CALENDAR_ID is not set" if @calendar_ids.empty?
    raise "GOOGLE_CLIENT_ID is not set" unless ENV["GOOGLE_CLIENT_ID"]
    raise "GOOGLE_CLIENT_SECRET is not set" unless ENV["GOOGLE_CLIENT_SECRET"]
    raise "Token file not found at #{TOKEN_PATH}. Run 'ruby setup_oauth.rb' first." unless File.exist?(TOKEN_PATH)
  end

  def fetch_calendar_data(calendar_id, time_min, time_max)
    calendar_list_entry = @service.get_calendar_list(calendar_id)
    events_response = @service.list_events(
      calendar_id,
      max_results: 100,
      single_events: true,
      order_by: "startTime",
      time_min: time_min,
      time_max: time_max
    )

    build_calendar_data(calendar_list_entry, events_response)
  rescue StandardError => e
    build_error_response(calendar_id, e.message)
  end

  def build_calendar_data(calendar_list_entry, events_response)
    calendar_name = calendar_list_entry.summary_override || calendar_list_entry.summary

    {
      id: calendar_list_entry.id,
      summary: calendar_name,
      description: calendar_list_entry.description,
      timezone: calendar_list_entry.time_zone,
      events: events_response.items.map { |event| build_event_data(event) }
    }
  end

  def build_event_data(event)
    {
      id: event.id,
      summary: event.summary,
      description: event.description,
      start: format_event_time(event.start),
      end: format_event_time(event.end)
    }
  end

  def build_error_response(calendar_id, error_message)
    {
      id: calendar_id,
      summary: nil,
      description: nil,
      timezone: nil,
      error: error_message,
      events: []
    }
  end

  def display_events(calendars_data, date)
    output = {
      date: date,
      calendars: calendars_data
    }

    puts JSON.generate(output)
  end

  def format_event_time(event_time)
    {
      date_time: format_datetime(event_time.date_time),
      date: event_time.date
    }
  end

  def format_datetime(datetime)
    return nil if datetime.nil?

    datetime.iso8601
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    date = ARGV[0] || Date.today.to_s

    # Handle special keywords for relative dates
    date = case date.downcase
           when "y", "yesterday", "昨日"
             (Date.today - 1).to_s
           when "t", "tomorrow", "明日"
             (Date.today + 1).to_s
           else
             date # Pass through to Date.parse
           end

    # Validate date format
    Date.parse(date)

    fetcher = GoogleCalendarFetcher.new
    fetcher.fetch_events(date)
  rescue Date::Error
    puts JSON.generate({ error: "Invalid date format. Please use YYYY-MM-DD format." })
    exit 1
  rescue StandardError => e
    puts JSON.generate({ error: e.message })
    exit 1
  end
end
