#!/usr/bin/env ruby
# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "json"
require "optparse"

# GoogleCalendarDeleter deletes events from Google Calendar
class GoogleCalendarDeleter
  APPLICATION_NAME = "Google Calendar Deleter"
  TOKEN_PATH = File.join(Dir.home, ".credentials", "calendar-readwrite-token.yaml")
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR

  VALID_SEND_UPDATES = %w[all externalOnly none].freeze

  # Google Calendarイベント削除クラスを初期化する
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

  # カレンダーからイベントを削除する
  #
  # @param event_id [String] 削除するイベントのID
  # @param send_updates [String] 通知設定（all, externalOnly, none）
  # @return [void]
  def delete_event(event_id:, send_updates: "none")
    validate_send_updates(send_updates)

    @service.delete_event(@calendar_id, event_id, send_updates: send_updates)

    display_result(event_id)
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

  # 削除結果をJSON形式で出力する
  #
  # @param event_id [String] 削除されたイベントID
  # @return [void]
  def display_result(event_id)
    output = {
      success: true,
      deleted_event_id: event_id
    }

    puts JSON.generate(output)
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
    opts.banner = "Usage: ruby google_calendar_deleter.rb [options]"
    define_required_options(opts, options)
    define_optional_options(opts, options)
    define_examples(opts)
  end
end

# 必須オプションを定義する
def define_required_options(opts, options)
  opts.separator ""
  opts.separator "Required options:"

  opts.on("--event-id=EVENT_ID", "Event ID to delete (required)") { |v| options[:event_id] = v }
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
  opts.separator "  ruby google_calendar_deleter.rb --event-id='abc123xyz'"
  opts.separator ""
  opts.separator "  ruby google_calendar_deleter.rb --event-id='abc123xyz' --send-updates=all"
end

# 必須オプションが指定されているか検証する
#
# @param options [Hash] 解析されたオプション
# @param parser [OptionParser] パーサーインスタンス
def validate_required_options(options, parser)
  return if options[:event_id]

  warn "Missing required option: --event-id"
  warn ""
  warn parser.help
  exit 1
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    options = parse_options

    deleter = GoogleCalendarDeleter.new(calendar_id: options[:calendar_id])
    deleter.delete_event(
      event_id: options[:event_id],
      send_updates: options[:send_updates]
    )
  rescue StandardError => e
    puts JSON.generate({ error: e.message })
    exit 1
  end
end
