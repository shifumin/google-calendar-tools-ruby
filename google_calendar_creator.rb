#!/usr/bin/env ruby
# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "date"
require "json"
require "optparse"

# GoogleCalendarCreator creates events in Google Calendar
class GoogleCalendarCreator
  APPLICATION_NAME = "Google Calendar Creator"
  TOKEN_PATH = File.join(Dir.home, ".credentials", "calendar-readwrite-token.yaml")
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR

  # Google Calendarイベント作成クラスを初期化する
  #
  # @param calendar_id [String, nil] カレンダーID（nilの場合は環境変数から取得）
  # @raise [RuntimeError] 必要な環境変数が設定されていない場合
  # @raise [RuntimeError] 認証トークンファイルが見つからない場合
  def initialize(calendar_id: nil)
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
    @calendar_id = resolve_calendar_id(calendar_id)

    validate_configuration
  end

  # カレンダーにイベントを作成する
  #
  # @param summary [String] イベントのタイトル
  # @param start_time [String] 開始日時（ISO 8601形式）
  # @param end_time [String] 終了日時（ISO 8601形式）
  # @param description [String, nil] イベントの説明
  # @param location [String, nil] イベントの場所
  # @return [void]
  def create_event(summary:, start_time:, end_time:, description: nil, location: nil)
    event = build_event(summary, start_time, end_time, description, location)
    result = @service.insert_event(@calendar_id, event)

    display_result(result)
  end

  private

  # カレンダーIDを決定する
  #
  # 優先順位:
  # 1. 引数で指定されたID
  # 2. GOOGLE_CALENDAR_ID環境変数
  # 3. GOOGLE_CALENDAR_IDS環境変数の最初の値
  #
  # @param calendar_id [String, nil] 引数で指定されたカレンダーID
  # @return [String, nil] 決定されたカレンダーID
  def resolve_calendar_id(calendar_id)
    return calendar_id if calendar_id

    if ENV["GOOGLE_CALENDAR_ID"]
      ENV["GOOGLE_CALENDAR_ID"]
    elsif ENV["GOOGLE_CALENDAR_IDS"]
      ENV["GOOGLE_CALENDAR_IDS"].split(",").first&.strip
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

    raise "No credentials found. Run 'ruby google_calendar_creator_authenticator.rb' first." if credentials.nil?

    credentials
  end

  # 設定が正しいことを検証する
  #
  # @raise [RuntimeError] 必要な環境変数が設定されていない場合
  # @raise [RuntimeError] トークンファイルが見つからない場合
  def validate_configuration
    raise "Calendar ID is not set. Use --calendar option or set GOOGLE_CALENDAR_ID" unless @calendar_id
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
  # @param description [String, nil] イベントの説明
  # @param location [String, nil] イベントの場所
  # @return [Google::Apis::CalendarV3::Event] イベントオブジェクト
  def build_event(summary, start_time, end_time, description, location)
    Google::Apis::CalendarV3::Event.new(
      summary: summary,
      description: description,
      location: location,
      start: build_event_datetime(start_time),
      end: build_event_datetime(end_time)
    )
  end

  # イベント日時オブジェクトを構築する
  #
  # YYYY-MM-DD形式の場合は終日イベント、YYYY-MM-DDTHH:MM:SS形式の場合は時刻指定イベントとして処理
  #
  # @param time_str [String] 日付または日時文字列
  # @return [Google::Apis::CalendarV3::EventDateTime] イベント日時オブジェクト
  def build_event_datetime(time_str)
    if all_day_format?(time_str)
      build_all_day_datetime(time_str)
    else
      build_timed_datetime(time_str)
    end
  end

  # 終日イベント形式（YYYY-MM-DD）かどうかを判定する
  #
  # @param time_str [String] 日付または日時文字列
  # @return [Boolean] 終日イベント形式の場合はtrue
  def all_day_format?(time_str)
    time_str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
  end

  # 終日イベント用のEventDateTimeを構築する
  #
  # @param date_str [String] 日付文字列（YYYY-MM-DD形式）
  # @return [Google::Apis::CalendarV3::EventDateTime] イベント日時オブジェクト
  def build_all_day_datetime(date_str)
    Google::Apis::CalendarV3::EventDateTime.new(date: date_str)
  end

  # 時刻指定イベント用のEventDateTimeを構築する
  #
  # @param time_str [String] 日時文字列
  # @return [Google::Apis::CalendarV3::EventDateTime] イベント日時オブジェクト
  def build_timed_datetime(time_str)
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
        description: event.description,
        location: event.location,
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

# コマンドライン引数を解析する
#
# @return [Hash] 解析されたオプション
def parse_options
  options = {}
  parser = build_option_parser(options)
  parser.parse!
  validate_required_options(options, parser)
  options
end

# OptionParserを構築する
#
# @param options [Hash] オプションを格納するハッシュ
# @return [OptionParser] 構築されたパーサー
def build_option_parser(options)
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby google_calendar_creator.rb [options]"
    define_required_options(opts, options)
    define_optional_options(opts, options)
    define_examples(opts)
  end
end

# 必須オプションを定義する
def define_required_options(opts, options)
  opts.separator ""
  opts.separator "Required options:"

  opts.on("--summary=SUMMARY", "Event title (required)") { |v| options[:summary] = v }
  opts.on("--start=DATETIME", "Start datetime, e.g., '2025-11-24T10:00:00' (required)") { |v| options[:start_time] = v }
  opts.on("--end=DATETIME", "End datetime, e.g., '2025-11-24T11:00:00' (required)") { |v| options[:end_time] = v }
end

# オプション項目を定義する
def define_optional_options(opts, options)
  opts.separator ""
  opts.separator "Optional:"

  opts.on("--description=DESCRIPTION", "Event description") { |v| options[:description] = v }
  opts.on("--location=LOCATION", "Event location (e.g., 'Tokyo Office 3F Room A')") { |v| options[:location] = v }
  opts.on("--calendar=CALENDAR_ID", "Calendar ID (default: GOOGLE_CALENDAR_ID env var)") do |v|
    options[:calendar_id] = v
  end
end

# 使用例を定義する
def define_examples(opts)
  opts.separator ""
  opts.separator "Examples:"
  opts.separator "  ruby google_calendar_creator.rb \\"
  opts.separator "    --summary='Meeting' --start='2025-11-24T10:00:00' --end='2025-11-24T11:00:00'"
  opts.separator ""
  opts.separator "  ruby google_calendar_creator.rb \\"
  opts.separator "    --summary='Meeting' --start='2025-11-24T10:00:00' --end='2025-11-24T11:00:00' \\"
  opts.separator "    --location='Tokyo Office 3F Room A'"
  opts.separator ""
  opts.separator "  ruby google_calendar_creator.rb \\"
  opts.separator "    --summary='Meeting' --start='2025-11-24T10:00:00' --end='2025-11-24T11:00:00' \\"
  opts.separator "    --calendar='your_calendar_id@group.calendar.google.com'"
end

# 必須オプションが指定されているか検証する
#
# @param options [Hash] 解析されたオプション
# @param parser [OptionParser] パーサーインスタンス
def validate_required_options(options, parser)
  missing = []
  missing << "--summary" unless options[:summary]
  missing << "--start" unless options[:start_time]
  missing << "--end" unless options[:end_time]

  return if missing.empty?

  warn "Missing required options: #{missing.join(', ')}"
  warn ""
  warn parser.help
  exit 1
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    options = parse_options

    creator = GoogleCalendarCreator.new(calendar_id: options[:calendar_id])
    creator.create_event(
      summary: options[:summary],
      start_time: options[:start_time],
      end_time: options[:end_time],
      description: options[:description],
      location: options[:location]
    )
  rescue StandardError => e
    puts JSON.generate({ error: e.message })
    exit 1
  end
end
