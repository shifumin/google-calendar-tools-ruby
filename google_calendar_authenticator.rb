#!/usr/bin/env ruby
# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "optparse"

# GoogleCalendarAuthenticator handles the OAuth 2.0 authentication flow for Google Calendar API
# Supports both read-only (fetcher) and read-write (creator) modes
class GoogleCalendarAuthenticator
  OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
  CREDENTIALS_DIR = File.join(Dir.home, ".credentials")

  MODES = {
    readonly: {
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY,
      token_file: "calendar-readonly-token.yaml",
      app_name: "Google Calendar Fetcher",
      description: "read-only"
    },
    readwrite: {
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR,
      token_file: "calendar-readwrite-token.yaml",
      app_name: "Google Calendar Creator",
      description: "read-write"
    }
  }.freeze

  # Google Calendar認証器を初期化する
  #
  # @param mode [Symbol] 認証モード（:readonly または :readwrite）
  # @raise [RuntimeError] 無効なモードが指定された場合
  # @raise [RuntimeError] 必要な環境変数が設定されていない場合
  def initialize(mode: :readonly)
    @mode = mode
    validate_mode
    validate_environment
    ensure_credentials_directory
  end

  # Google Calendar API用のOAuth 2.0認証を実行する
  #
  # 既に認証情報が存在する場合は、認証済みであることを示すメッセージを表示する
  # そうでない場合は、ブラウザを開いて認証コードの入力を促すOAuthフローを開始する
  #
  # @return [void]
  def authenticate
    client_id = Google::Auth::ClientId.new(
      ENV.fetch("GOOGLE_CLIENT_ID", nil),
      ENV.fetch("GOOGLE_CLIENT_SECRET", nil)
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(file: token_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
    user_id = "default"

    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      perform_authentication(authorizer, user_id)
    else
      show_already_authenticated_message
    end
  end

  private

  def config
    MODES[@mode]
  end

  def scope
    config[:scope]
  end

  def token_path
    File.join(CREDENTIALS_DIR, config[:token_file])
  end

  def app_name
    config[:app_name]
  end

  def mode_description
    config[:description]
  end

  # 対話型のOAuth認証フローを実行する
  #
  # 認証URLを含むブラウザウィンドウを開き、ユーザーに認証コードの入力を促し、
  # 将来の使用のために認証情報を保存する
  #
  # @param authorizer [Google::Auth::UserAuthorizer] OAuthオーソライザインスタンス
  # @param user_id [String] 認証情報保存用のユーザー識別子
  # @return [void]
  def perform_authentication(authorizer, user_id)
    puts "=== Google Calendar OAuth 2.0 Setup (#{mode_description}) ===\n",
         "Opening authorization URL in your browser...\n",
         "If the browser doesn't open automatically, please copy and paste this URL:"

    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts url, "\n"

    open_browser(url)

    puts "After authorizing, enter the authorization code:"
    code = gets.chomp

    authorizer.get_and_store_credentials_from_code(
      user_id: user_id,
      code: code,
      base_url: OOB_URI
    )

    puts "\n",
         "✓ Authentication successful!\n",
         "✓ Token saved to: #{token_path}\n",
         "You can now run 'ruby #{target_script}' to #{target_action}."
  end

  def target_script
    @mode == :readonly ? "google_calendar_fetcher.rb" : "google_calendar_creator.rb"
  end

  def target_action
    @mode == :readonly ? "fetch your calendar events" : "create calendar events"
  end

  def show_already_authenticated_message
    puts "✓ Already authenticated (#{mode_description})!\n",
         "Token file: #{token_path}\n",
         "If you want to re-authenticate, delete the token file and run this script again."
  end

  # デフォルトブラウザで認証URLを開く
  #
  # OSを検出して適切なコマンドを使用してブラウザを開く
  # macOS (darwin)、Linux、Windowsプラットフォームをサポート
  #
  # @param url [String] 開く認証URL
  # @return [void]
  def open_browser(url)
    case RUBY_PLATFORM
    when /darwin/
      system("open '#{url}'")
    when /linux/
      system("xdg-open '#{url}'")
    when /mingw|mswin/
      system("start '#{url}'")
    end
  end

  # モードが有効であることを検証する
  #
  # @raise [RuntimeError] 無効なモードが指定された場合
  # @return [void]
  def validate_mode
    return if MODES.key?(@mode)

    raise "Invalid mode: #{@mode}. Valid modes are: #{MODES.keys.join(', ')}"
  end

  # 必要な環境変数が設定されていることを検証する
  #
  # @raise [RuntimeError] GOOGLE_CLIENT_IDまたはGOOGLE_CLIENT_SECRETが設定されていない場合
  # @return [void]
  def validate_environment
    raise "GOOGLE_CLIENT_ID is not set" unless ENV["GOOGLE_CLIENT_ID"]
    raise "GOOGLE_CLIENT_SECRET is not set" unless ENV["GOOGLE_CLIENT_SECRET"]
  end

  def ensure_credentials_directory
    FileUtils.mkdir_p(CREDENTIALS_DIR) unless File.directory?(CREDENTIALS_DIR)
  end
end

# コマンドライン引数を解析する
#
# @return [Symbol] 認証モード
def parse_mode
  mode = :readonly

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby google_calendar_authenticator.rb [options]"

    opts.on("--mode=MODE", "Authentication mode: readonly (default) or readwrite") do |v|
      mode = v.to_sym
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end

    opts.separator ""
    opts.separator "Examples:"
    opts.separator "  ruby google_calendar_authenticator.rb                  # read-only (for fetcher)"
    opts.separator "  ruby google_calendar_authenticator.rb --mode=readonly  # read-only (for fetcher)"
    opts.separator "  ruby google_calendar_authenticator.rb --mode=readwrite # read-write (for creator)"
  end.parse!

  mode
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    mode = parse_mode
    authenticator = GoogleCalendarAuthenticator.new(mode: mode)
    authenticator.authenticate
  rescue StandardError => e
    puts "Error: #{e.message}"
    exit 1
  end
end
