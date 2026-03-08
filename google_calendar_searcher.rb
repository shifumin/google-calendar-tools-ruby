#!/usr/bin/env ruby
# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "date"
require "json"
require "optparse"

# GoogleCalendarSearcher searches events from Google Calendar across a date range
class GoogleCalendarSearcher
  APPLICATION_NAME = "Google Calendar Searcher"
  TOKEN_PATH = File.join(Dir.home, ".credentials", "calendar-readonly-token.yaml")
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

  # Google Calendarイベント検索クラスを初期化する
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

  # 指定された期間のカレンダーイベントを検索してJSON形式で出力する
  #
  # @param from_date [String] 開始日（YYYY-MM-DD形式）
  # @param to_date [String] 終了日（YYYY-MM-DD形式）
  # @param query [String, nil] テキスト検索クエリ
  # @return [void]
  def search_events(from_date:, to_date:, query: nil)
    time_min = DateTime.parse("#{from_date}T00:00:00+09:00").rfc3339
    time_max = DateTime.parse("#{to_date}T23:59:59+09:00").rfc3339

    all_events = @calendar_ids.flat_map do |calendar_id|
      fetch_all_events(calendar_id, time_min, time_max, query)
    end

    sorted_events = sort_events(all_events)
    display_results(sorted_events, from_date, to_date, query)
  end

  private

  # 環境変数からカレンダーIDのリストを解析する
  #
  # @return [Array<String>] カレンダーIDの配列
  def parse_calendar_ids
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

    credentials = authorizer.get_credentials("default")

    if credentials.nil?
      raise "No credentials found. Please run 'ruby google_calendar_authenticator.rb' first to authenticate."
    end

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
    raise "Token file not found. Run 'ruby google_calendar_authenticator.rb' first." unless File.exist?(TOKEN_PATH)
  end

  # 指定されたカレンダーの全イベントをページネーション付きで取得する
  #
  # @param calendar_id [String] カレンダーID
  # @param time_min [String] 開始時刻（RFC3339形式）
  # @param time_max [String] 終了時刻（RFC3339形式）
  # @param query [String, nil] テキスト検索クエリ
  # @return [Array<Hash>] イベントデータの配列
  def fetch_all_events(calendar_id, time_min, time_max, query)
    entry = @service.get_calendar_list(calendar_id)
    calendar_info = { id: entry.id, name: entry.summary_override || entry.summary }
    events = paginated_list_events(calendar_id, time_min, time_max, query)

    events.map { |event| build_event_data(event, calendar_info) }
  rescue StandardError => e
    [{ error: e.message, calendar_id: calendar_id }]
  end

  # ページネーション付きでイベントを取得する
  #
  # @param calendar_id [String] カレンダーID
  # @param time_min [String] 開始時刻（RFC3339形式）
  # @param time_max [String] 終了時刻（RFC3339形式）
  # @param query [String, nil] テキスト検索クエリ
  # @return [Array<Google::Apis::CalendarV3::Event>] イベントの配列
  def paginated_list_events(calendar_id, time_min, time_max, query)
    all_items = []
    page_token = nil

    loop do
      response = @service.list_events(
        calendar_id,
        single_events: true, order_by: "startTime",
        time_min: time_min, time_max: time_max,
        q: query, max_results: 2500, page_token: page_token
      )
      all_items.concat(response.items)
      page_token = response.next_page_token
      break unless page_token
    end

    all_items
  end

  # イベントオブジェクトからイベントデータを構築する
  #
  # @param event [Google::Apis::CalendarV3::Event] イベントオブジェクト
  # @param calendar_info [Hash] カレンダー情報
  # @return [Hash] イベントデータ
  def build_event_data(event, calendar_info)
    {
      id: event.id,
      summary: event.summary,
      description: event.description,
      location: event.location,
      start: format_event_time(event.start),
      end: format_event_time(event.end),
      event_type: event.event_type,
      calendar_id: calendar_info[:id],
      calendar_name: calendar_info[:name]
    }
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

  # イベントを時系列順にソートする
  #
  # @param events [Array<Hash>] イベントデータの配列
  # @return [Array<Hash>] ソート済みイベントデータの配列
  def sort_events(events)
    events.sort_by do |event|
      next "" if event[:error]

      event.dig(:start, :date_time) || event.dig(:start, :date).to_s
    end
  end

  # 検索結果をJSON形式で出力する
  #
  # @param events [Array<Hash>] ソート済みイベントデータの配列
  # @param from_date [String] 開始日
  # @param to_date [String] 終了日
  # @param query [String, nil] 検索クエリ
  # @return [void]
  def display_results(events, from_date, to_date, query)
    output = {
      search: {
        from: from_date,
        to: to_date,
        query: query,
        total_events: events.count { |e| !e[:error] }
      },
      events: events
    }

    puts JSON.generate(output)
  end
end

# 日付キーワードをDateオブジェクトに変換する
#
# @param str [String] 日付文字列（YYYY-MM-DD形式またはキーワード）
# @return [Date] 解析された日付
# @raise [Date::Error] 日付形式が不正な場合
def parse_date_argument(str)
  case str.downcase
  when "today", "今日" then Date.today
  when "yesterday", "昨日", "y" then Date.today - 1
  when "tomorrow", "明日", "t" then Date.today + 1
  when "明後日" then Date.today + 2
  else Date.parse(str)
  end
end

# 相対期間文字列を日数またはMonth数に変換する
#
# @param value [String] 期間文字列（例: "3months", "2weeks", "30days"）
# @return [Array<Symbol, Integer>] [:months, N] または [:days, N]
# @raise [RuntimeError] 不正な期間形式の場合
def parse_period(value)
  match = value.match(/\A(\d+)(months?|weeks?|days?)\z/i)
  raise "Invalid period format: '#{value}'. Use formats like '3months', '2weeks', '30days'." unless match

  count = match[1].to_i
  unit = match[2].downcase.sub(/s\z/, "")

  case unit
  when "month" then [:months, count]
  when "week" then [:days, count * 7]
  when "day" then [:days, count]
  end
end

# 期間指定から日付範囲を計算する
#
# @param period [String] 期間文字列
# @param direction [Symbol] :last または :next
# @return [Array<Date, Date>] [from_date, to_date]
def calculate_date_range(period, direction)
  unit, count = parse_period(period)

  case direction
  when :last
    to_date = Date.today
    from_date = unit == :months ? (to_date << count) : (to_date - count)
  when :next
    from_date = Date.today
    to_date = unit == :months ? (from_date >> count) : (from_date + count)
  end

  [from_date, to_date]
end

# コマンドライン引数を解析する
#
# @return [Hash] 解析されたオプション
def parse_options
  options = {}
  parser = build_option_parser(options)
  parser.parse!
  resolve_date_range(options, parser)
  options
end

# OptionParserを構築する
#
# @param options [Hash] オプションを格納するハッシュ
# @return [OptionParser] 構築されたパーサー
def build_option_parser(options)
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby google_calendar_searcher.rb [options]"
    define_date_range_options(opts, options)
    define_period_options(opts, options)
    define_search_options(opts, options)
    define_examples(opts)
  end
end

# 日付範囲オプションを定義する
def define_date_range_options(opts, options)
  opts.separator ""
  opts.separator "Date range (use --from/--to OR --last/--next):"

  opts.on("--from=DATE", "Start date (YYYY-MM-DD, today, tomorrow, etc.)") { |v| options[:from] = v }
  opts.on("--to=DATE", "End date (YYYY-MM-DD, today, tomorrow, etc.)") { |v| options[:to] = v }
end

# 期間オプションを定義する
def define_period_options(opts, options)
  opts.on("--last=PERIOD", "Past period (e.g., 3months, 2weeks, 30days)") { |v| options[:last] = v }
  opts.on("--next=PERIOD", "Future period (e.g., 3months, 2weeks, 30days)") { |v| options[:next] = v }
end

# 検索オプションを定義する
def define_search_options(opts, options)
  opts.separator ""
  opts.separator "Search:"

  opts.on("--query=TEXT", "Free text search (searches summary, description, location)") do |v|
    options[:query] = v
  end
end

# 使用例を定義する
def define_examples(opts)
  opts.separator ""
  opts.separator "Examples:"
  opts.separator "  ruby google_calendar_searcher.rb --from=2026-01-01 --to=2026-03-31"
  opts.separator "  ruby google_calendar_searcher.rb --last=3months --query='meeting'"
  opts.separator "  ruby google_calendar_searcher.rb --next=2weeks"
end

# オプションから日付範囲を解決する
#
# @param options [Hash] 解析されたオプション
# @param parser [OptionParser] パーサーインスタンス
def resolve_date_range(options, parser)
  has_from_to = options[:from] || options[:to]
  has_period = options[:last] || options[:next]

  if has_from_to && has_period
    abort_with_help("Cannot use --from/--to and --last/--next together.", parser)
  elsif has_period
    resolve_period_options(options, parser)
  elsif has_from_to
    resolve_from_to_options(options, parser)
  else
    abort_with_help("Specify date range with --from/--to or --last/--next.", parser)
  end
end

# 期間オプションから日付範囲を解決する
def resolve_period_options(options, parser)
  abort_with_help("Cannot use --last and --next together.", parser) if options[:last] && options[:next]

  direction = options[:last] ? :last : :next
  period = options[:last] || options[:next]
  options[:from_date], options[:to_date] = calculate_date_range(period, direction)
end

# from/toオプションから日付範囲を解決する
def resolve_from_to_options(options, parser)
  abort_with_help("Both --from and --to are required.", parser) unless options[:from] && options[:to]

  options[:from_date] = parse_date_argument(options[:from])
  options[:to_date] = parse_date_argument(options[:to])
end

# エラーメッセージとヘルプを表示して終了する
def abort_with_help(message, parser)
  warn message
  warn ""
  warn parser.help
  exit 1
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    options = parse_options

    searcher = GoogleCalendarSearcher.new
    searcher.search_events(
      from_date: options[:from_date].to_s,
      to_date: options[:to_date].to_s,
      query: options[:query]
    )
  rescue Date::Error
    puts JSON.generate({ error: "Invalid date format. Please use YYYY-MM-DD format." })
    exit 1
  rescue StandardError => e
    puts JSON.generate({ error: e.message })
    exit 1
  end
end
