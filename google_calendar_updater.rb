#!/usr/bin/env ruby
# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "date"
require "json"
require "optparse"

# GoogleCalendarUpdater updates events in Google Calendar
class GoogleCalendarUpdater
  APPLICATION_NAME = "Google Calendar Updater"
  TOKEN_PATH = File.join(Dir.home, ".credentials", "calendar-creator-token.yaml")
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR

  VALID_SEND_UPDATES = %w[all externalOnly none].freeze

  # Google Calendarイベント更新クラスを初期化する
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

  # カレンダーのイベントを更新する
  #
  # @param event_id [String] 更新するイベントのID
  # @param fields [Hash] 更新フィールド（summary, start_time, end_time, description, location）
  # @param send_updates [String] 通知設定（all, externalOnly, none）
  # @return [void]
  def update_event(event_id:, fields:, send_updates: "none")
    validate_send_updates(send_updates)

    event = build_patch_event(fields)
    result = @service.patch_event(@calendar_id, event_id, event, send_updates: send_updates)

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

    if credentials.nil?
      raise "No credentials found. Run 'ruby google_calendar_authenticator.rb --mode=readwrite' first."
    end

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

    raise "Token file not found. Run 'ruby google_calendar_authenticator.rb --mode=readwrite' first."
  end

  # sendUpdatesパラメータが有効な値かを検証する
  #
  # @param send_updates [String] 検証する値
  # @raise [RuntimeError] 無効な値が指定された場合
  def validate_send_updates(send_updates)
    return if VALID_SEND_UPDATES.include?(send_updates)

    raise "Invalid send_updates value: #{send_updates}. Valid values are: #{VALID_SEND_UPDATES.join(', ')}"
  end

  # PATCH用のイベントオブジェクトを構築する
  #
  # @param fields [Hash] 更新フィールド
  # @return [Google::Apis::CalendarV3::Event] イベントオブジェクト
  def build_patch_event(fields)
    event = Google::Apis::CalendarV3::Event.new

    event.summary = fields[:summary] if fields[:summary]
    event.description = fields[:description] if fields[:description]
    event.location = fields[:location] if fields[:location]
    event.start = build_event_datetime(fields[:start_time]) if fields[:start_time]
    event.end = build_event_datetime(fields[:end_time]) if fields[:end_time]

    event
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

  # 更新結果をJSON形式で出力する
  #
  # @param event [Google::Apis::CalendarV3::Event] 更新されたイベント
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
  options = { send_updates: "none" }
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
    opts.banner = "Usage: ruby google_calendar_updater.rb [options]"
    define_required_options(opts, options)
    define_update_options(opts, options)
    define_optional_options(opts, options)
    define_examples(opts)
  end
end

# 必須オプションを定義する
def define_required_options(opts, options)
  opts.separator ""
  opts.separator "Required options:"

  opts.on("--event-id=EVENT_ID", "Event ID to update (required)") { |v| options[:event_id] = v }
end

# 更新対象フィールドのオプションを定義する
def define_update_options(opts, options)
  opts.separator ""
  opts.separator "Update fields (at least one required):"

  opts.on("--summary=SUMMARY", "New event title") { |v| options[:summary] = v }
  opts.on("--start=DATETIME", "New start datetime, e.g., '2025-01-15T10:00:00'") { |v| options[:start_time] = v }
  opts.on("--end=DATETIME", "New end datetime, e.g., '2025-01-15T11:00:00'") { |v| options[:end_time] = v }
  opts.on("--description=DESCRIPTION", "New event description") { |v| options[:description] = v }
  opts.on("--location=LOCATION", "New event location") { |v| options[:location] = v }
end

# オプション項目を定義する
def define_optional_options(opts, options)
  opts.separator ""
  opts.separator "Optional:"

  opts.on("--calendar=CALENDAR_ID", "Calendar ID (default: GOOGLE_CALENDAR_ID env var)") do |v|
    options[:calendar_id] = v
  end
  opts.on("--send-updates=VALUE", "Notification setting: all, externalOnly, none (default: none)") do |v|
    options[:send_updates] = v
  end
end

# 使用例を定義する
def define_examples(opts)
  opts.separator ""
  opts.separator "Examples:"
  opts.separator "  ruby google_calendar_updater.rb --event-id='abc123' --summary='New Title'"
  opts.separator ""
  opts.separator "  ruby google_calendar_updater.rb --event-id='abc123' \\"
  opts.separator "    --start='2025-01-15T14:00:00' --end='2025-01-15T15:00:00'"
  opts.separator ""
  opts.separator "  ruby google_calendar_updater.rb --event-id='abc123' \\"
  opts.separator "    --summary='Updated Meeting' --location='Room B' --send-updates=all"
end

# 必須オプションが指定されているか検証する
#
# @param options [Hash] 解析されたオプション
# @param parser [OptionParser] パーサーインスタンス
def validate_required_options(options, parser)
  unless options[:event_id]
    warn "Missing required option: --event-id"
    warn ""
    warn parser.help
    exit 1
  end

  update_fields = %i[summary start_time end_time description location]
  return if update_fields.any? { |field| options[field] }

  warn "At least one update field is required (--summary, --start, --end, --description, or --location)"
  warn ""
  warn parser.help
  exit 1
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    options = parse_options

    updater = GoogleCalendarUpdater.new(calendar_id: options[:calendar_id])
    fields = {
      summary: options[:summary],
      start_time: options[:start_time],
      end_time: options[:end_time],
      description: options[:description],
      location: options[:location]
    }.compact
    updater.update_event(
      event_id: options[:event_id],
      fields: fields,
      send_updates: options[:send_updates]
    )
  rescue StandardError => e
    puts JSON.generate({ error: e.message })
    exit 1
  end
end
