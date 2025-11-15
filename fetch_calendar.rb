#!/usr/bin/env ruby
# frozen_string_literal: true

require 'google/apis/calendar_v3'
require 'googleauth'
require 'dotenv/load'
require 'date'

# GoogleCalendarFetcher fetches events from Google Calendar for a specified date
class GoogleCalendarFetcher
  APPLICATION_NAME = 'Google Calendar Fetcher'
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
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(ENV['GOOGLE_APPLICATION_CREDENTIALS']),
      scope: SCOPE
    )
    authorizer.fetch_access_token!
    authorizer
  end

  def validate_configuration
    raise 'GOOGLE_CALENDAR_ID is not set' unless @calendar_id
    raise 'GOOGLE_APPLICATION_CREDENTIALS is not set' unless ENV['GOOGLE_APPLICATION_CREDENTIALS']
    raise 'Credentials file not found' unless File.exist?(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
  end

  def display_events(events, date)
    if events.empty?
      puts "No events found for #{date}"
      return
    end

    puts "\n=== Events for #{date} (#{events.size} events) ===\n\n"

    events.each_with_index do |event, index|
      start_time = event.start.date_time || event.start.date
      end_time = event.end.date_time || event.end.date

      puts "[#{index + 1}] #{event.summary}"
      puts "    Start: #{format_time(start_time)}"
      puts "    End:   #{format_time(end_time)}"
      puts "    Description: #{event.description}" if event.description
      puts
    end
  end

  def format_time(time)
    return time if time.is_a?(String)

    time.strftime('%Y-%m-%d %H:%M')
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
    puts "Error: Invalid date format. Please use YYYY-MM-DD format."
    puts "Usage: ruby fetch_calendar.rb [YYYY-MM-DD]"
    exit 1
  rescue StandardError => e
    puts "Error: #{e.message}"
    exit 1
  end
end
