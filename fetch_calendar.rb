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

  # Google Calendarイベント取得クラスを初期化する
  #
  # @raise [RuntimeError] 必要な環境変数が設定されていない場合
  # @raise [RuntimeError] 認証トークンファイルが見つからない場合
  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
    @calendar_ids = parse_calendar_ids

    validate_configuration
  end

  # 指定された日付のカレンダーイベントを取得してJSON形式で出力する
  #
  # @param date [String] イベントを取得する日付（YYYY-MM-DD形式）
  # @return [void]
  def fetch_events(date)
    time_min = DateTime.parse("#{date}T00:00:00+09:00").rfc3339
    time_max = DateTime.parse("#{date}T23:59:59+09:00").rfc3339

    calendars_data = @calendar_ids.map do |calendar_id|
      fetch_calendar_data(calendar_id, time_min, time_max)
    end

    display_events(calendars_data, date)
  end

  private

  # 環境変数からカレンダーIDのリストを解析する
  #
  # GOOGLE_CALENDAR_IDS（カンマ区切り）またはGOOGLE_CALENDAR_ID（単一）をサポート
  #
  # @return [Array<String>] カレンダーIDの配列
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

  # OAuth 2.0認証を実行して認証情報を取得する
  #
  # @return [Google::Auth::UserRefreshCredentials] 認証情報
  # @raise [RuntimeError] 認証情報が見つからない場合
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

  # 設定が正しいことを検証する
  #
  # @raise [RuntimeError] 必要な環境変数が設定されていない場合
  # @raise [RuntimeError] トークンファイルが見つからない場合
  def validate_configuration
    raise "GOOGLE_CALENDAR_IDS or GOOGLE_CALENDAR_ID is not set" if @calendar_ids.empty?
    raise "GOOGLE_CLIENT_ID is not set" unless ENV["GOOGLE_CLIENT_ID"]
    raise "GOOGLE_CLIENT_SECRET is not set" unless ENV["GOOGLE_CLIENT_SECRET"]
    raise "Token file not found at #{TOKEN_PATH}. Run 'ruby setup_oauth.rb' first." unless File.exist?(TOKEN_PATH)
  end

  # 指定されたカレンダーのデータとイベントを取得する
  #
  # @param calendar_id [String] カレンダーID
  # @param time_min [String] 開始時刻（RFC3339形式）
  # @param time_max [String] 終了時刻（RFC3339形式）
  # @return [Hash] カレンダーデータ（メタデータとイベント）またはエラー情報
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

  # カレンダーメタデータとイベントからカレンダーデータを構築する
  #
  # @param calendar_list_entry [Google::Apis::CalendarV3::CalendarListEntry] カレンダーリストエントリ
  # @param events_response [Google::Apis::CalendarV3::Events] イベントレスポンス
  # @return [Hash] カレンダーデータ（ID、名前、説明、タイムゾーン、イベント）
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

  # イベントオブジェクトからイベントデータを構築する
  #
  # @param event [Google::Apis::CalendarV3::Event] イベントオブジェクト
  # @return [Hash] イベントデータ（ID、タイトル、説明、開始・終了時刻）
  def build_event_data(event)
    {
      id: event.id,
      summary: event.summary,
      description: event.description,
      start: format_event_time(event.start),
      end: format_event_time(event.end)
    }
  end

  # カレンダー取得エラー時のレスポンスを構築する
  #
  # @param calendar_id [String] カレンダーID
  # @param error_message [String] エラーメッセージ
  # @return [Hash] エラー情報を含むカレンダーデータ
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

  # イベント時刻をハッシュ形式に変換する
  #
  # @param event_time [Google::Apis::CalendarV3::EventDateTime] イベント日時オブジェクト
  # @return [Hash] 日時情報（date_timeとdate）
  def format_event_time(event_time)
    {
      date_time: format_datetime(event_time.date_time),
      date: event_time.date
    }
  end

  # DateTimeオブジェクトをISO 8601形式の文字列に変換する
  #
  # @param datetime [DateTime, nil] DateTimeオブジェクト
  # @return [String, nil] ISO 8601形式の文字列、またはnil
  def format_datetime(datetime)
    return nil if datetime.nil?

    datetime.iso8601
  end

  # カレンダーデータをJSON形式で出力する
  #
  # @param calendars_data [Array<Hash>] カレンダーデータの配列
  # @param date [String] 取得日付
  # @return [void]
  def display_events(calendars_data, date)
    output = {
      date: date,
      calendars: calendars_data
    }

    puts JSON.generate(output)
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    # Handle special keywords for relative dates
    date_obj = case (ARGV[0] || "").downcase
               when "y", "yesterday", "昨日"
                 Date.today - 1
               when "t", "tomorrow", "明日"
                 Date.today + 1
               when ""
                 Date.today
               else
                 Date.parse(ARGV[0])
               end

    fetcher = GoogleCalendarFetcher.new
    fetcher.fetch_events(date_obj.to_s)
  rescue Date::Error
    puts JSON.generate({ error: "Invalid date format. Please use YYYY-MM-DD format." })
    exit 1
  rescue StandardError => e
    puts JSON.generate({ error: e.message })
    exit 1
  end
end
