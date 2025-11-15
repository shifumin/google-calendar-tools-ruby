#!/usr/bin/env ruby
# frozen_string_literal: true

require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'date'
require 'json'

# GoogleCalendarFetcher fetches events from Google Calendar for a specified date
class GoogleCalendarFetcher
  APPLICATION_NAME = 'Google Calendar Fetcher'
  TOKEN_PATH = File.join(Dir.home, '.credentials', 'calendar-fetcher-token.yaml')
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
    @calendar_id = ENV['GOOGLE_CALENDAR_ID']

    validate_configuration
  end

  def fetch_events(date)
    time_min = DateTime.parse("#{date}T00:00:00+09:00").rfc3339
    time_max = DateTime.parse("#{date}T23:59:59+09:00").rfc3339

    response = @service.list_events(
      @calendar_id,
      max_results: 100,
      single_events: true,
      order_by: 'startTime',
      time_min: time_min,
      time_max: time_max
    )

    display_events(response.items, date)
  end

  private

  def authorize
    client_id = Google::Auth::ClientId.new(
      ENV['GOOGLE_CLIENT_ID'],
      ENV['GOOGLE_CLIENT_SECRET']
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)

    if credentials.nil?
      raise "No credentials found. Please run 'ruby setup_oauth.rb' first to authenticate."
    end

    credentials
  end

  def validate_configuration
    raise 'GOOGLE_CALENDAR_ID is not set' unless @calendar_id
    raise 'GOOGLE_CLIENT_ID is not set' unless ENV['GOOGLE_CLIENT_ID']
    raise 'GOOGLE_CLIENT_SECRET is not set' unless ENV['GOOGLE_CLIENT_SECRET']
    raise "Token file not found at #{TOKEN_PATH}. Run 'ruby setup_oauth.rb' first." unless File.exist?(TOKEN_PATH)
  end

  def display_events(events, date)
    output = {
      date: date,
      events: events.map do |event|
        {
          id: event.id,
          summary: event.summary,
          start_time: format_time_iso8601(event.start.date_time || event.start.date),
          end_time: format_time_iso8601(event.end.date_time || event.end.date)
        }
      end
    }

    puts JSON.generate(output)
  end

  def format_time_iso8601(time)
    return time.to_s if time.is_a?(String)

    time.iso8601
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    date = ARGV[0] || Date.today.to_s

    # Validate date format
    Date.parse(date)

    fetcher = GoogleCalendarFetcher.new
    fetcher.fetch_events(date)
  rescue Date::Error
    puts JSON.generate({ error: 'Invalid date format. Please use YYYY-MM-DD format.' })
    exit 1
  rescue StandardError => e
    puts JSON.generate({ error: e.message })
    exit 1
  end
end
