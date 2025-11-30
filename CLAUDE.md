# CLAUDE.md

このファイルはClaude Codeがこのリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

Google Calendar APIを使ったRubyツール。OAuth 2.0認証でカレンダーイベントの取得・作成を行う。

### 主要ファイル

| ファイル | 説明 |
|---------|------|
| `google_calendar_fetcher.rb` | イベント取得（読み取り専用） |
| `google_calendar_creator.rb` | イベント作成 |
| `google_calendar_authenticator.rb` | OAuth認証（`--mode`で読み取り専用/書き込み権限を切替） |

## 技術スタック

- Ruby >= 3.4.0
- google-apis-calendar_v3（Google Calendar API）
- googleauth（OAuth 2.0認証）
- mise（環境変数管理）
- rubocop（リンター）

## コマンド

```bash
# 依存関係インストール
bundle install

# リンター実行
bundle exec rubocop

# リンター自動修正
bundle exec rubocop -a

# イベント取得（今日）
mise exec -- ruby google_calendar_fetcher.rb

# イベント取得（指定日）
mise exec -- ruby google_calendar_fetcher.rb 2025-01-15

# イベント作成
mise exec -- ruby google_calendar_creator.rb \
  --summary='Meeting' \
  --start='2025-01-15T10:00:00' \
  --end='2025-01-15T11:00:00'
```

## コーディング規約

### RuboCop設定（.rubocop.yml）

- 行長: 最大120文字
- 文字列リテラル: ダブルクォート統一
- frozen_string_literal: 必須
- メソッド長: 最大30行
- ABC複雑度: 最大30
- クラス長: 最大110行

### スタイルガイド

- クラス/モジュールのドキュメントコメントは任意
- YARDスタイルのコメントを使用（@param, @return, @raise）
- 出力はJSON形式で統一

## 環境変数

`mise.local.toml`で管理（.gitignoreに含まれる）:

| 変数名 | 説明 |
|--------|------|
| `GOOGLE_CALENDAR_IDS` | カレンダーID（カンマ区切りで複数可） |
| `GOOGLE_CALENDAR_ID` | カレンダーID（単一、後方互換用） |
| `GOOGLE_CLIENT_ID` | OAuth Client ID |
| `GOOGLE_CLIENT_SECRET` | OAuth Client Secret |

## 認証トークンの保存先

- Fetcher: `~/.credentials/calendar-fetcher-token.yaml`
- Creator: `~/.credentials/calendar-creator-token.yaml`

## 注意事項

- `mise.local.toml`と認証トークンファイルはコミットしない
- テストファイルは現在存在しない
