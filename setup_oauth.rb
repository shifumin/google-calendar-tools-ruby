#!/usr/bin/env ruby
# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"

# OAuthSetup handles the initial OAuth 2.0 authentication flow
class OAuthSetup
  OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
  APPLICATION_NAME = "Google Calendar Fetcher"
  TOKEN_PATH = File.join(Dir.home, ".credentials", "calendar-fetcher-token.yaml")
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

  # OAuth認証セットアップハンドラを初期化する
  #
  # @raise [RuntimeError] 必要な環境変数が設定されていない場合
  def initialize
    validate_environment
    ensure_credentials_directory
  end

  # Google Calendar API用のOAuth 2.0認証フローを実行する
  #
  # 既に認証情報が存在する場合は、認証済みであることを示すメッセージを表示する
  # そうでない場合は、ブラウザを開いて認証コードの入力を促すOAuthフローを開始する
  #
  # @return [void]
  def setup
    client_id = Google::Auth::ClientId.new(
      ENV.fetch("GOOGLE_CLIENT_ID", nil),
      ENV.fetch("GOOGLE_CLIENT_SECRET", nil)
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = "default"

    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      perform_authentication(authorizer, user_id)
    else
      show_already_authenticated_message
    end
  end

  private

  # 対話型のOAuth認証フローを実行する
  #
  # 認証URLを含むブラウザウィンドウを開き、ユーザーに認証コードの入力を促し、
  # 将来の使用のために認証情報を保存する
  #
  # @param authorizer [Google::Auth::UserAuthorizer] OAuthオーソライザインスタンス
  # @param user_id [String] 認証情報保存用のユーザー識別子
  # @return [void]
  def perform_authentication(authorizer, user_id)
    puts "\n=== Google Calendar OAuth 2.0 Setup ===\n\n",
         "Opening authorization URL in your browser...\n",
         "If the browser doesn't open automatically, please copy and paste this URL:"

    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts url, ""

    open_browser(url)

    puts "After authorizing, enter the authorization code:"
    code = gets.chomp

    authorizer.get_and_store_credentials_from_code(
      user_id: user_id,
      code: code,
      base_url: OOB_URI
    )

    puts "\n✓ Authentication successful!\n",
         "✓ Token saved to: #{TOKEN_PATH}\n",
         "You can now run 'ruby fetch_calendar.rb' to fetch your calendar events."
  end

  def show_already_authenticated_message
    puts "✓ Already authenticated!\n",
         "Token file: #{TOKEN_PATH}\n",
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
    system("open '#{url}'") if RUBY_PLATFORM.include?("darwin")
    system("xdg-open '#{url}'") if RUBY_PLATFORM.include?("linux")
    system("start '#{url}'") if RUBY_PLATFORM.include?("mingw") || RUBY_PLATFORM.include?("mswin")
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
    credentials_dir = File.dirname(TOKEN_PATH)
    FileUtils.mkdir_p(credentials_dir) unless File.directory?(credentials_dir)
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    setup = OAuthSetup.new
    setup.setup
  rescue StandardError => e
    puts "Error: #{e.message}"
    exit 1
  end
end
