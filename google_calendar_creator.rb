#!/usr/bin/env ruby
# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "date"
require "json"

# GoogleCalendarCreator creates events in Google Calendar
class GoogleCalendarCreator
  APPLICATION_NAME = "Google Calendar Fetcher"
  TOKEN_PATH = File.join(Dir.home, ".credentials", "calendar-creator-token.yaml")
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR

  # Google Calendarイベント作成クラスを初期化する
  #
  # @raise [RuntimeError] 必要な環境変数が設定されていない場合
  # @raise [RuntimeError] 認証トークンファイルが見つからない場合
  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
    @calendar_id = ENV.fetch("GOOGLE_CALENDAR_ID", nil)

    validate_configuration
  end

  # カレンダーにイベントを作成する
  #
  # @param summary [String] イベントのタイトル
  # @param start_time [String] 開始日時（ISO 8601形式）
  # @param end_time [String] 終了日時（ISO 8601形式）
  # @return [void]
  def create_event(summary:, start_time:, end_time:)
    event = build_event(summary, start_time, end_time)
    result = @service.insert_event(@calendar_id, event)

    display_result(result)
  end

  private

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

    raise "No credentials found. Run 'ruby google_calendar_creator_authenticator.rb' first." if credentials.nil?

    credentials
  end

  # 設定が正しいことを検証する
  #
  # @raise [RuntimeError] 必要な環境変数が設定されていない場合
  # @raise [RuntimeError] トークンファイルが見つからない場合
  def validate_configuration
    raise "GOOGLE_CALENDAR_ID is not set" unless @calendar_id
    raise "GOOGLE_CLIENT_ID is not set" unless ENV["GOOGLE_CLIENT_ID"]
    raise "GOOGLE_CLIENT_SECRET is not set" unless ENV["GOOGLE_CLIENT_SECRET"]
    return if File.exist?(TOKEN_PATH)

    raise "Token file not found. Run 'ruby google_calendar_creator_authenticator.rb' first."
  end

  # イベントオブジェクトを構築する
  #
  # @param summary [String] イベントのタイトル
  # @param start_time [String] 開始日時
  # @param end_time [String] 終了日時
  # @return [Google::Apis::CalendarV3::Event] イベントオブジェクト
  def build_event(summary, start_time, end_time)
    Google::Apis::CalendarV3::Event.new(
      summary: summary,
      start: build_event_datetime(start_time),
      end: build_event_datetime(end_time)
    )
  end

  # イベント日時オブジェクトを構築する
  #
  # @param time_str [String] 日時文字列
  # @return [Google::Apis::CalendarV3::EventDateTime] イベント日時オブジェクト
  def build_event_datetime(time_str)
    datetime = DateTime.parse(time_str)
    # タイムゾーンが指定されていない場合はJSTを付与
    datetime = DateTime.parse("#{time_str}+09:00") unless time_str.match?(/[+-]\d{2}:\d{2}|Z$/)

    Google::Apis::CalendarV3::EventDateTime.new(
      date_time: datetime.rfc3339,
      time_zone: "Asia/Tokyo"
    )
  end

  # 作成結果をJSON形式で出力する
  #
  # @param event [Google::Apis::CalendarV3::Event] 作成されたイベント
  # @return [void]
  def display_result(event)
    output = {
      success: true,
      event: {
        id: event.id,
        summary: event.summary,
        start: format_event_time(event.start),
        end: format_event_time(event.end),
        html_link: event.html_link
      }
    }

    puts JSON.generate(output)
  end

  # イベント時刻をハッシュ形式に変換する
  #
  # @param event_time [Google::Apis::CalendarV3::EventDateTime] イベント日時オブジェクト
  # @return [Hash] 日時情報（date_timeとdate）
  def format_event_time(event_time)
    {
      date_time: event_time.date_time&.iso8601,
      date: event_time.date
    }
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    if ARGV.length < 3
      error_output = {
        error: "Usage: ruby google_calendar_creator.rb 'タイトル' '開始日時' '終了日時'",
        example: "ruby google_calendar_creator.rb 'ミーティング' '2025-11-24T10:00:00' '2025-11-24T11:00:00'"
      }
      puts JSON.generate(error_output)
      exit 1
    end

    summary = ARGV[0]
    start_time = ARGV[1]
    end_time = ARGV[2]

    creator = GoogleCalendarCreator.new
    creator.create_event(summary: summary, start_time: start_time, end_time: end_time)
  rescue StandardError => e
    puts JSON.generate({ error: e.message })
    exit 1
  end
end
