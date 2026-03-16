# google-calendar-tools-ruby

Ruby CLI tools for Google Calendar. Fetch, search, create, update, and delete events via OAuth 2.0. All output is structured JSON.

## Prerequisites

- Ruby >= 3.4.0
- Google Cloud Project with Calendar API enabled

## Setup

### 1. Install and Configure

```bash
bundle install
```

Set environment variables using mise, direnv, or shell export:

```bash
export GOOGLE_CALENDAR_IDS="cal1@gmail.com,cal2@gmail.com"
export GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-client-secret"
```

> `mise.local.toml`, `.envrc`, and `.env` are gitignored.

**Finding your Calendar ID:** Google Calendar → Settings → select calendar → "Integrate calendar" → Calendar ID.

### 2. Create OAuth 2.0 Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → "APIs & Services" → "Library"
2. Enable **Google Calendar API**
3. Go to "Credentials" → "Create Credentials" → "OAuth client ID"
4. Configure OAuth consent screen if prompted (add your email to "Test users")
5. Select **Desktop app**, create, and copy Client ID / Client Secret

### 3. Authenticate

```bash
# Read-only (for fetcher/searcher)
ruby google_calendar_authenticator.rb

# Read-write (for creator/updater/deleter)
ruby google_calendar_authenticator.rb --mode=readwrite
```

## Usage

### Fetcher

```bash
ruby google_calendar_fetcher.rb                  # Today
ruby google_calendar_fetcher.rb 2025-01-15       # Specific date
ruby google_calendar_fetcher.rb tomorrow          # Relative dates (see -h)
```

### Searcher

```bash
ruby google_calendar_searcher.rb --from=2025-01-01 --to=2025-03-31
ruby google_calendar_searcher.rb --last=3months
ruby google_calendar_searcher.rb --next=2weeks --query='Meeting'
```

### Creator

```bash
ruby google_calendar_creator.rb \
  --summary='Meeting' \
  --start='2025-01-15T10:00:00' \
  --end='2025-01-15T11:00:00'

# Optional: --description, --location, --calendar
# All-day event: --start='2025-01-15' --end='2025-01-16'
```

### Updater

```bash
ruby google_calendar_updater.rb --event-id='abc123' --summary='New Title'

# Optional: --start, --end, --description, --location, --calendar
# --send-updates=all|externalOnly|none (default: none)
```

### Deleter

```bash
ruby google_calendar_deleter.rb --event-id='abc123'

# Optional: --calendar, --send-updates=all|externalOnly|none
```

Run any script with `-h` for full option details.

## License

MIT
