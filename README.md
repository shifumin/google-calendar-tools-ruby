# google-calendar-tools-ruby

A Ruby toolkit to fetch, create, and delete Google Calendar events using OAuth 2.0 authentication. Outputs structured JSON format optimized for AI/LLM consumption.

## Features

### Event Fetcher
- Fetch Google Calendar events for a specified date
- Support for multiple calendars
- **JSON output format** (optimized for AI agents and programmatic processing)
- Includes calendar metadata (name, timezone, description)
- Includes event details (summary, description, timestamps)

### Event Creator
- Create events in Google Calendar
- Support for timed events and all-day events
- Optional event description and location
- Specify target calendar via command line or environment variable

### Event Deleter
- Delete events from Google Calendar
- Control notification settings for attendees
- Specify target calendar via command line or environment variable

### Common Features
- Uses Google Calendar API v3
- OAuth 2.0 authentication (Google's recommended method)
- Secure token-based authentication with automatic refresh
- Environment variable-based configuration

## Prerequisites

- Ruby 3.4.0 or higher
- Google Cloud Project with Calendar API enabled
- Google account with calendar access
- Environment variable management tool (optional, any of the following):
  - [mise](https://mise.jdx.dev/)
  - [direnv](https://direnv.net/)
  - Or simply export variables in your shell

## Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Google Cloud Console Setup

#### Create a Project and Enable API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google Calendar API**:
   - Go to "APIs & Services" → "Library"
   - Search for "Google Calendar API"
   - Click "Enable"

#### Create OAuth 2.0 Credentials

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth client ID"
3. If prompted, configure the OAuth consent screen:
   - User Type: Select "External" (or "Internal" for Google Workspace)
   - Fill in the required fields (App name, User support email, etc.)
   - Add your email to "Test users" if using External user type
   - Click "Save and Continue"
4. For Application type, select **"Desktop app"**
5. Give it a name (e.g., "Calendar Fetcher")
6. Click "Create"
7. Download the credentials JSON file or copy the Client ID and Client Secret

### 3. Environment Variables

Set the following environment variables using your preferred method:

**Required environment variables:**
- `GOOGLE_CALENDAR_IDS`: Multiple calendar IDs, comma-separated (e.g., "cal1@gmail.com,cal2@gmail.com")
- `GOOGLE_CALENDAR_ID`: Single calendar ID (for backward compatibility)
- `GOOGLE_CLIENT_ID`: OAuth 2.0 Client ID from Google Cloud Console
- `GOOGLE_CLIENT_SECRET`: OAuth 2.0 Client Secret from Google Cloud Console

**How to find your Calendar ID:**
1. Open Google Calendar
2. Go to "Settings" → select your calendar
3. Scroll down to "Integrate calendar"
4. Copy the "Calendar ID" (usually your email address for the primary calendar)

#### Option A: Using mise (recommended)

Create a `mise.local.toml` file in the project root:

```toml
[env]
GOOGLE_CALENDAR_IDS = "your-email@gmail.com,work-calendar@example.com"
GOOGLE_CLIENT_ID = "your-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET = "your-client-secret"
```

Then run scripts with `mise exec -- ruby script.rb` or activate mise in your shell.

#### Option B: Using direnv

Create a `.envrc` file in the project root:

```bash
export GOOGLE_CALENDAR_IDS="your-email@gmail.com,work-calendar@example.com"
export GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-client-secret"
```

Then run `direnv allow` to load the variables.

#### Option C: Using shell export

Add to your shell configuration (`~/.bashrc`, `~/.zshrc`, etc.) or run directly:

```bash
export GOOGLE_CALENDAR_IDS="your-email@gmail.com,work-calendar@example.com"
export GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-client-secret"
```

**Note:** `mise.local.toml`, `.envrc`, and `.env` are already in `.gitignore` and will not be committed to version control.

### 4. Initial Authentication

#### For Event Fetcher (Read-only access)

Run the authentication script to authenticate and save your credentials:

```bash
ruby google_calendar_authenticator.rb
```

This will:
1. Open your default browser with Google's authorization page
2. Ask you to sign in and grant calendar read permission
3. Save the refresh token to `~/.credentials/calendar-fetcher-token.yaml`

#### For Event Creator (Write access)

Run the authentication script with `--mode=readwrite`:

```bash
ruby google_calendar_authenticator.rb --mode=readwrite
```

This will:
1. Open your default browser with Google's authorization page
2. Ask you to sign in and grant calendar write permission
3. Save the refresh token to `~/.credentials/calendar-creator-token.yaml`

**Important:** Add your email to "Test users" in the OAuth consent screen if you see an "Access blocked" error.

**Note:** You only need to do this once per tool. The token will be automatically refreshed when needed.

## Usage

Make sure environment variables are set before running scripts.

### Event Fetcher

After completing the setup, run the script with a date argument:

#### Specific Date

```bash
ruby google_calendar_fetcher.rb 2025-01-15
```

#### Relative Dates

```bash
# Yesterday
ruby google_calendar_fetcher.rb y
ruby google_calendar_fetcher.rb yesterday

# Tomorrow
ruby google_calendar_fetcher.rb t
ruby google_calendar_fetcher.rb tomorrow
```

#### Today (Default)

Run without arguments to fetch today's events:

```bash
ruby google_calendar_fetcher.rb
```

### Event Creator

Create events using command-line options:

#### Timed Event

```bash
ruby google_calendar_creator.rb \
  --summary='Team Meeting' \
  --start='2025-01-15T10:00:00' \
  --end='2025-01-15T11:00:00'
```

#### Timed Event with Description

```bash
ruby google_calendar_creator.rb \
  --summary='Team Meeting' \
  --start='2025-01-15T10:00:00' \
  --end='2025-01-15T11:00:00' \
  --description='Weekly team sync to discuss project progress'
```

#### Timed Event with Location

```bash
ruby google_calendar_creator.rb \
  --summary='Team Meeting' \
  --start='2025-01-15T10:00:00' \
  --end='2025-01-15T11:00:00' \
  --location='Tokyo Office 3F Room A'
```

#### All-day Event

```bash
ruby google_calendar_creator.rb \
  --summary='Company Holiday' \
  --start='2025-01-15' \
  --end='2025-01-16'
```

#### Specify Calendar

```bash
ruby google_calendar_creator.rb \
  --summary='Meeting' \
  --start='2025-01-15T10:00:00' \
  --end='2025-01-15T11:00:00' \
  --calendar='your-calendar-id@group.calendar.google.com'
```

#### Command-line Options

| Option | Required | Description |
|--------|----------|-------------|
| `--summary` | Yes | Event title |
| `--start` | Yes | Start datetime (e.g., `2025-01-15T10:00:00`) or date for all-day events (e.g., `2025-01-15`) |
| `--end` | Yes | End datetime or date (exclusive for all-day events) |
| `--description` | No | Event description |
| `--location` | No | Event location (e.g., `Tokyo Office 3F Room A`) |
| `--calendar` | No | Calendar ID (defaults to `GOOGLE_CALENDAR_ID` env var) |

### Event Deleter

Delete events using the event ID (obtained from the fetcher):

#### Basic Delete

```bash
ruby google_calendar_deleter.rb --event-id='abc123xyz'
```

#### Delete with Notification

```bash
ruby google_calendar_deleter.rb --event-id='abc123xyz' --send-updates=all
```

#### Command-line Options

| Option | Required | Description |
|--------|----------|-------------|
| `--event-id` | Yes | Event ID to delete (get from fetcher output) |
| `--calendar` | No | Calendar ID (defaults to `GOOGLE_CALENDAR_ID` env var) |
| `--send-updates` | No | Notification setting: `all`, `externalOnly`, `none` (default: `none`) |

**send-updates values:**
- `all`: Notify all attendees
- `externalOnly`: Notify only non-Google Calendar users
- `none`: No notifications (default, recommended for batch operations)

## Output

All scripts output **structured JSON format** optimized for AI agents and programmatic processing.

### Fetcher JSON Structure

The output structure mirrors Google Calendar API's event format for consistency. When multiple calendars are configured, events are grouped by calendar:

```json
{
  "date": "2025-01-15",
  "calendars": [
    {
      "id": "your-email@gmail.com",
      "summary": "Primary Calendar",
      "description": "Calendar description (if set)",
      "timezone": "Asia/Tokyo",
      "events": [
        {
          "id": "event_unique_id",
          "summary": "Team Meeting",
          "description": "Weekly team sync",
          "start": {
            "date_time": "2025-01-15T10:00:00+09:00",
            "date": null
          },
          "end": {
            "date_time": "2025-01-15T11:00:00+09:00",
            "date": null
          },
          "event_type": "default"
        }
      ]
    },
    {
      "id": "work@example.com",
      "summary": "Work Calendar",
      "description": null,
      "timezone": "Asia/Tokyo",
      "events": [
        {
          "id": "event_unique_id_2",
          "summary": "All-day Event",
          "description": null,
          "start": {
            "date_time": null,
            "date": "2025-01-15"
          },
          "end": {
            "date_time": null,
            "date": "2025-01-16"
          },
          "event_type": "default"
        }
      ]
    }
  ]
}
```

### Creator JSON Structure

```json
{
  "success": true,
  "event": {
    "id": "event_unique_id",
    "summary": "Team Meeting",
    "description": "Weekly team sync",
    "location": "Tokyo Office 3F Room A",
    "start": {
      "date_time": "2025-01-15T10:00:00+09:00",
      "date": null
    },
    "end": {
      "date_time": "2025-01-15T11:00:00+09:00",
      "date": null
    },
    "html_link": "https://www.google.com/calendar/event?eid=..."
  }
}
```

### Output Fields

**Top-level fields (Fetcher):**
- `date`: The date for which events were fetched (YYYY-MM-DD format)
- `calendars`: Array of calendar objects with their events

**Top-level fields (Creator):**
- `success`: Boolean indicating if the event was created successfully
- `event`: The created event object

**Calendar metadata (per calendar, Fetcher only):**
- `id`: Calendar identifier
- `summary`: Calendar name (uses custom name if set via CalendarList API)
- `description`: Calendar description (null if not set)
- `timezone`: IANA timezone (e.g., "Asia/Tokyo")
- `events`: Array of events for this calendar
- `error`: Error message if calendar fetch failed (only present on error)

**Event details (per event):**
- `id`: Unique event identifier from Google Calendar
- `summary`: Event title
- `description`: Event description (null if not set)
- `location`: Event location (null if not set, Creator only)
- `start`: Event start time object
  - `date_time`: ISO 8601 timestamp with timezone (for timed events)
  - `date`: Date in YYYY-MM-DD format (for all-day events)
- `end`: Event end time object
  - `date_time`: ISO 8601 timestamp with timezone (for timed events)
  - `date`: Date in YYYY-MM-DD format (for all-day events, **exclusive**)
- `event_type`: Event type from Google Calendar API (`default`, `outOfOffice`, `focusTime`, `workingLocation`) (Fetcher only)
- `html_link`: URL to view the event in Google Calendar (Creator only)

**Important:**
- For all-day events, exactly one of `date_time` or `date` will be set, the other will be `null`.
- The `end.date` for all-day events is **exclusive** (e.g., an all-day event on January 15 has `end.date` of "2025-01-16").
- Events are grouped by calendar and sorted chronologically within each calendar.

### Event Type Examples

**Timed Event (specific start/end times):**
```json
{
  "summary": "Team Meeting",
  "start": {"date_time": "2025-01-15T10:00:00+09:00", "date": null},
  "end": {"date_time": "2025-01-15T11:00:00+09:00", "date": null},
  "event_type": "default"
}
```

**All-day Event (single day):**
```json
{
  "summary": "Holiday",
  "start": {"date_time": null, "date": "2025-01-15"},
  "end": {"date_time": null, "date": "2025-01-16"},
  "event_type": "default"
}
```

**Multi-day All-day Event:**
```json
{
  "summary": "Conference (Jan 14-16)",
  "start": {"date_time": null, "date": "2025-01-14"},
  "end": {"date_time": null, "date": "2025-01-17"},
  "event_type": "default"
}
```

**Multi-day Timed Event:**
```json
{
  "summary": "Weekend Trip",
  "start": {"date_time": "2025-01-14T10:00:00+09:00", "date": null},
  "end": {"date_time": "2025-01-16T18:00:00+09:00", "date": null},
  "event_type": "default"
}
```

### Processing JSON Output

You can pipe the output to `jq` for processing:

```bash
# Pretty-print JSON
ruby google_calendar_fetcher.rb | jq

# Get all events from all calendars
ruby google_calendar_fetcher.rb | jq '.calendars[].events[]'

# Extract event titles from all calendars
ruby google_calendar_fetcher.rb | jq '.calendars[].events[].summary'

# Get events from a specific calendar
ruby google_calendar_fetcher.rb | jq '.calendars[] | select(.id == "your-email@gmail.com") | .events'

# Get all-day events only
ruby google_calendar_fetcher.rb | jq '.calendars[].events[] | select(.start.date != null)'

# Get timed events only
ruby google_calendar_fetcher.rb | jq '.calendars[].events[] | select(.start.date_time != null)'

# Count total events across all calendars
ruby google_calendar_fetcher.rb | jq '[.calendars[].events[]] | length'

# Count events per calendar
ruby google_calendar_fetcher.rb | jq '.calendars[] | {calendar: .summary, count: (.events | length)}'
```

## Troubleshooting

### "Access blocked: Calendar Fetcher Ruby has not completed the Google verification process"
Add your email address to "Test users" in the OAuth consent screen:
1. Go to Google Cloud Console → "APIs & Services" → "OAuth consent screen"
2. Scroll down to "Test users"
3. Click "+ ADD USERS"
4. Enter your email address
5. Save and try authenticating again

### "No credentials found" error
Run the appropriate authentication script first:
- For Fetcher: `ruby google_calendar_authenticator.rb`
- For Creator: `ruby google_calendar_authenticator.rb --mode=readwrite`

### "Token file not found" error
The token files should be at:
- Fetcher: `~/.credentials/calendar-fetcher-token.yaml`
- Creator: `~/.credentials/calendar-creator-token.yaml`

Run the appropriate authentication script to create them.

### "Access denied" or permission errors
1. Make sure you granted the correct permission during OAuth setup (read-only for Fetcher, write for Creator)
2. Check that your Calendar ID is correct in `mise.local.toml`
3. Try re-authenticating by deleting the token file and running the authentication script again

### Browser doesn't open automatically
Copy the URL from the terminal and paste it into your browser manually.

### Environment variables not loaded
Make sure your environment variables are set. Check with:
```bash
echo $GOOGLE_CLIENT_ID
```
If using mise, run scripts with `mise exec -- ruby script.rb` or activate mise in your shell with `mise activate`.

## Security Notes

- **Never commit** the following to version control:
  - `mise.local.toml` (contains OAuth credentials)
  - Token files in `~/.credentials/`
  - OAuth client credentials
- `mise.local.toml` is already in `.gitignore` for your protection
- Keep your OAuth credentials secure and rotate them if compromised
- The refresh token allows access to your calendar without re-authentication, so protect it carefully

## How It Works

This toolkit uses **OAuth 2.0** authentication, which is Google's recommended method for accessing user data:

1. **Initial Setup** (Authentication scripts):
   - Opens Google's authorization page in your browser
   - You grant permission for the app to access your calendar (read-only or read-write)
   - Google returns a refresh token that is saved locally

2. **Fetching Events** (`google_calendar_fetcher.rb`):
   - Loads credentials from environment variables
   - Uses the saved refresh token to get a short-lived access token
   - Fetches calendar metadata using CalendarList API
   - Fetches calendar events for the specified date using Events API
   - Outputs structured JSON with calendar and event information
   - Automatically refreshes the access token when it expires

3. **Creating Events** (`google_calendar_creator.rb`):
   - Loads credentials from environment variables
   - Uses the saved refresh token to get a short-lived access token
   - Creates a new event using Events API
   - Outputs structured JSON with the created event information
   - Automatically refreshes the access token when it expires

This approach is more secure than service accounts for personal calendars and follows Google's best practices.

## Use Cases

This toolkit is designed for:
- **AI agents** that need to access and manage calendar information programmatically
- **Automation scripts** that process or create calendar events
- **Data analysis** of calendar patterns
- **Integration** with other tools and services

The JSON output format makes it easy to parse and process calendar data in any programming language or AI system.

## License

MIT License - see [LICENSE](LICENSE) file for details
