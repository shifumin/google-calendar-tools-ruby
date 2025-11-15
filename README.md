# google-calendar-fetcher-ruby

A Ruby script to fetch Google Calendar events for a specific date using OAuth 2.0 authentication. Outputs structured JSON format optimized for AI/LLM consumption.

## Features

- Fetch Google Calendar events for a specified date
- **JSON output format** (optimized for AI agents and programmatic processing)
- Includes calendar metadata (name, timezone, description)
- Includes event details (summary, description, timestamps)
- Uses Google Calendar API v3
- OAuth 2.0 authentication (Google's recommended method)
- Secure token-based authentication with automatic refresh
- Environment variable-based configuration with mise

## Prerequisites

- Ruby 2.7 or higher
- [mise](https://mise.jdx.dev/) (for environment variable management)
- Google Cloud Project with Calendar API enabled
- Google account with calendar access

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

Create a `mise.local.toml` file in the project root with your credentials:

**Multiple calendars (comma-separated):**
```toml
[env]
GOOGLE_CALENDAR_IDS = "your-email@gmail.com,work-calendar@example.com,another@gmail.com"
GOOGLE_CLIENT_ID = "your-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET = "your-client-secret"
```

**Single calendar (backward compatibility):**
```toml
[env]
GOOGLE_CALENDAR_ID = "your-email@gmail.com"
GOOGLE_CLIENT_ID = "your-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET = "your-client-secret"
```

**Environment variables:**
- `GOOGLE_CALENDAR_IDS`: Multiple calendar IDs, comma-separated (e.g., "cal1@gmail.com,cal2@gmail.com")
- `GOOGLE_CALENDAR_ID`: Single calendar ID (for backward compatibility)
- `GOOGLE_CLIENT_ID`: OAuth 2.0 Client ID from Google Cloud Console
- `GOOGLE_CLIENT_SECRET`: OAuth 2.0 Client Secret from Google Cloud Console

**How to find your Calendar ID:**
1. Open Google Calendar
2. Go to "Settings" → select your calendar
3. Scroll down to "Integrate calendar"
4. Copy the "Calendar ID" (usually your email address for the primary calendar)

**Note:** `mise.local.toml` is already in `.gitignore` and will not be committed to version control.

### 4. Initial Authentication

Run the setup script to authenticate and save your credentials:

```bash
mise exec -- ruby setup_oauth.rb
```

This will:
1. Open your default browser with Google's authorization page
2. Ask you to sign in and grant calendar read permission
3. Save the refresh token to `~/.credentials/calendar-fetcher-token.yaml`

**Important:** Add your email to "Test users" in the OAuth consent screen if you see an "Access blocked" error.

**Note:** You only need to do this once. The token will be automatically refreshed when needed.

## Usage

After completing the setup, run the script with a specific date:

```bash
mise exec -- ruby fetch_calendar.rb 2025-01-15
```

Or run without arguments to fetch today's events:

```bash
mise exec -- ruby fetch_calendar.rb
```

## Output

The script outputs **structured JSON format** optimized for AI agents and programmatic processing.

### JSON Structure

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
          }
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
          }
        }
      ]
    }
  ]
}
```

### Output Fields

**Top-level fields:**
- `date`: The date for which events were fetched (YYYY-MM-DD format)
- `calendars`: Array of calendar objects with their events

**Calendar metadata (per calendar):**
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
- `start`: Event start time object
  - `date_time`: ISO 8601 timestamp with timezone (for timed events)
  - `date`: Date in YYYY-MM-DD format (for all-day events)
- `end`: Event end time object
  - `date_time`: ISO 8601 timestamp with timezone (for timed events)
  - `date`: Date in YYYY-MM-DD format (for all-day events, **exclusive**)

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
  "end": {"date_time": "2025-01-15T11:00:00+09:00", "date": null}
}
```

**All-day Event (single day):**
```json
{
  "summary": "Holiday",
  "start": {"date_time": null, "date": "2025-01-15"},
  "end": {"date_time": null, "date": "2025-01-16"}
}
```

**Multi-day All-day Event:**
```json
{
  "summary": "Conference (Jan 14-16)",
  "start": {"date_time": null, "date": "2025-01-14"},
  "end": {"date_time": null, "date": "2025-01-17"}
}
```

**Multi-day Timed Event:**
```json
{
  "summary": "Weekend Trip",
  "start": {"date_time": "2025-01-14T10:00:00+09:00", "date": null},
  "end": {"date_time": "2025-01-16T18:00:00+09:00", "date": null}
}
```

### Processing JSON Output

You can pipe the output to `jq` for processing:

```bash
# Pretty-print JSON
mise exec -- ruby fetch_calendar.rb | jq

# Get all events from all calendars
mise exec -- ruby fetch_calendar.rb | jq '.calendars[].events[]'

# Extract event titles from all calendars
mise exec -- ruby fetch_calendar.rb | jq '.calendars[].events[].summary'

# Get events from a specific calendar
mise exec -- ruby fetch_calendar.rb | jq '.calendars[] | select(.id == "your-email@gmail.com") | .events'

# Get all-day events only
mise exec -- ruby fetch_calendar.rb | jq '.calendars[].events[] | select(.start.date != null)'

# Get timed events only
mise exec -- ruby fetch_calendar.rb | jq '.calendars[].events[] | select(.start.date_time != null)'

# Count total events across all calendars
mise exec -- ruby fetch_calendar.rb | jq '[.calendars[].events[]] | length'

# Count events per calendar
mise exec -- ruby fetch_calendar.rb | jq '.calendars[] | {calendar: .summary, count: (.events | length)}'
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
Run `mise exec -- ruby setup_oauth.rb` to authenticate first.

### "Token file not found" error
The token file should be at `~/.credentials/calendar-fetcher-token.yaml`. Run `mise exec -- ruby setup_oauth.rb` to create it.

### "Access denied" or permission errors
1. Make sure you granted calendar read permission during OAuth setup
2. Check that your Calendar ID is correct in `mise.local.toml`
3. Try re-authenticating by deleting `~/.credentials/calendar-fetcher-token.yaml` and running `mise exec -- ruby setup_oauth.rb` again

### Browser doesn't open automatically
Copy the URL from the terminal and paste it into your browser manually.

### Environment variables not loaded
Make sure you're using `mise exec --` prefix when running the scripts, or activate mise in your shell with `mise activate`.

## Security Notes

- **Never commit** the following to version control:
  - `mise.local.toml` (contains OAuth credentials)
  - Token files in `~/.credentials/`
  - OAuth client credentials
- `mise.local.toml` is already in `.gitignore` for your protection
- Keep your OAuth credentials secure and rotate them if compromised
- The refresh token allows access to your calendar without re-authentication, so protect it carefully

## How It Works

This script uses **OAuth 2.0** authentication, which is Google's recommended method for accessing user data:

1. **Initial Setup** (`setup_oauth.rb`):
   - Opens Google's authorization page in your browser
   - You grant permission for the app to read your calendar
   - Google returns a refresh token that is saved locally

2. **Fetching Events** (`fetch_calendar.rb`):
   - Loads credentials from environment variables (via mise)
   - Uses the saved refresh token to get a short-lived access token
   - Fetches calendar metadata using CalendarList API
   - Fetches calendar events for the specified date using Events API
   - Outputs structured JSON with calendar and event information
   - Automatically refreshes the access token when it expires

This approach is more secure than service accounts for personal calendars and follows Google's best practices.

## Use Cases

This script is designed for:
- **AI agents** that need to access calendar information programmatically
- **Automation scripts** that process calendar events
- **Data analysis** of calendar patterns
- **Integration** with other tools and services

The JSON output format makes it easy to parse and process calendar data in any programming language or AI system.

## License

MIT License - see [LICENSE](LICENSE) file for details
