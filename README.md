# google-calendar-fetcher-ruby

A Ruby script to fetch Google Calendar events for a specific date using OAuth 2.0 authentication.

## Features

- Fetch Google Calendar events for a specified date
- Uses Google Calendar API v3
- OAuth 2.0 authentication (Google's recommended method)
- Secure token-based authentication with automatic refresh
- Environment variable-based configuration

## Prerequisites

- Ruby 2.7 or higher
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

Set the following environment variables in your environment:

- `GOOGLE_CALENDAR_ID`: Your Google Calendar ID (usually your email address)
- `GOOGLE_CLIENT_ID`: OAuth 2.0 Client ID from Google Cloud Console
- `GOOGLE_CLIENT_SECRET`: OAuth 2.0 Client Secret from Google Cloud Console

**How to find your Calendar ID:**
1. Open Google Calendar
2. Go to "Settings" → select your calendar
3. Scroll down to "Integrate calendar"
4. Copy the "Calendar ID" (usually your email address for the primary calendar)

### 4. Initial Authentication

Run the setup script to authenticate and save your credentials:

```bash
ruby setup_oauth.rb
```

This will:
1. Open your default browser with Google's authorization page
2. Ask you to sign in and grant calendar read permission
3. Save the refresh token to `~/.credentials/calendar-fetcher-token.yaml`

**Note:** You only need to do this once. The token will be automatically refreshed when needed.

## Usage

After completing the setup, run the script with a specific date:

```bash
ruby fetch_calendar.rb 2025-01-15
```

Or run without arguments to fetch today's events:

```bash
ruby fetch_calendar.rb
```

## Output

The script will display:
- Event summary
- Start time
- End time
- Event description (if available)

Example output:
```
=== Events for 2025-01-15 (2 events) ===

[1] Team Meeting
    Start: 2025-01-15 10:00
    End:   2025-01-15 11:00
    Description: Weekly team sync

[2] Project Review
    Start: 2025-01-15 14:00
    End:   2025-01-15 15:00
```

## Troubleshooting

### "No credentials found" error
Run `ruby setup_oauth.rb` to authenticate first.

### "Token file not found" error
The token file should be at `~/.credentials/calendar-fetcher-token.yaml`. Run `ruby setup_oauth.rb` to create it.

### "Access denied" or permission errors
1. Make sure you granted calendar read permission during OAuth setup
2. Check that your Calendar ID is correct in `.env`
3. Try re-authenticating by deleting `~/.credentials/calendar-fetcher-token.yaml` and running `ruby setup_oauth.rb` again

### Browser doesn't open automatically
Copy the URL from the terminal and paste it into your browser manually.

## Security Notes

- **Never commit** the following to version control:
  - Environment variables with sensitive values
  - Token files in `~/.credentials/`
  - OAuth client credentials
- Keep your OAuth credentials secure and rotate them if compromised
- The refresh token allows access to your calendar without re-authentication, so protect it carefully

## How It Works

This script uses **OAuth 2.0** authentication, which is Google's recommended method for accessing user data:

1. **Initial Setup** (`setup_oauth.rb`):
   - Opens Google's authorization page in your browser
   - You grant permission for the app to read your calendar
   - Google returns a refresh token that is saved locally

2. **Fetching Events** (`fetch_calendar.rb`):
   - Uses the saved refresh token to get a short-lived access token
   - Fetches calendar events using the access token
   - Automatically refreshes the access token when it expires

This approach is more secure than service accounts for personal calendars and follows Google's best practices.

## License

MIT License - see [LICENSE](LICENSE) file for details
