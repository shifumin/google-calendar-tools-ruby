# google-calendar-fetcher-ruby

A Ruby script to fetch Google Calendar events for a specific date.

## Features

- Fetch Google Calendar events for a specified date
- Uses Google Calendar API v3
- Supports authentication via service account or OAuth2
- Environment variable-based configuration for secure credential management

## Prerequisites

- Ruby 2.7 or higher
- Google Cloud Project with Calendar API enabled
- Google service account credentials or OAuth2 credentials

## Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Google Calendar API Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Calendar API
4. Create credentials (Service Account or OAuth2)
5. Download the credentials JSON file

### 3. Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Edit `.env` and set the following variables:

- `GOOGLE_CALENDAR_ID`: Your Google Calendar ID (e.g., `your-email@gmail.com`)
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to your credentials JSON file

## Usage

Run the script with a specific date:

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

## Security Notes

- **Never commit** your `.env` file or credentials JSON to version control
- Keep your credentials secure and rotate them regularly
- Use service accounts for automation, OAuth2 for user-specific access

## License

MIT License - see [LICENSE](LICENSE) file for details
