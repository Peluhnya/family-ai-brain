# Family AI Brain

## AI configuration

The `AI застосунку — без власного ключа` account mode uses the application owner's OpenAI credentials. Configure them in one of these ways:

```yaml
# bin/rails credentials:edit
openai:
  api_key: sk-...
  chat_model: gpt-4o-mini
```

Environment variables override Rails credentials:

```bash
OPENAI_API_KEY=sk-... AI_CHAT_MODEL=gpt-4o-mini bin/dev
```

For Kamal deployments, export `OPENAI_API_KEY` before running `bin/kamal deploy`. `config/deploy.yml` passes it to the application as a secret.

Never commit a real API key to the repository. Account-specific keys entered through the UI are stored using Active Record Encryption.

## Google Calendar OAuth

Create a Web application OAuth client in Google Cloud, enable the Google Calendar API, and add this authorized redirect URI:

```text
https://YOUR_APP_HOST/calendar_connections/google_callback
```

Configure the client through Rails credentials:

```yaml
# bin/rails credentials:edit
google:
  client_id: your-client-id.apps.googleusercontent.com
  client_secret: your-client-secret
```

Environment variables override credentials:

```bash
GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... bin/dev
```

In a family's **Calendar connections** tab, click **Підключити Google Calendar**, authorize the Google account, and select the calendar to attach to that family. The app requests read-only calendar access and stores OAuth tokens encrypted with Active Record Encryption.

## Outlook Calendar OAuth

Register a Web application in Microsoft Entra ID, add the delegated Microsoft Graph permission `Calendars.Read`, and configure this redirect URI:

```text
https://YOUR_APP_HOST/calendar_connections/outlook_callback
```

Provide credentials through `MICROSOFT_CLIENT_ID` and `MICROSOFT_CLIENT_SECRET`, or Rails credentials:

```yaml
microsoft:
  client_id: your-application-client-id
  client_secret: your-client-secret
```

In **Calendar connections**, click **Підключити Outlook Calendar**, authorize the Microsoft account, and select one or more calendars. The app requests read-only calendar and offline access, refreshes tokens when needed, and stores tokens encrypted with Active Record Encryption.

## Apple Calendar (iCloud CalDAV)

Apple Calendar is connected with an Apple ID and an app-specific password. Create the password in the Apple Account security settings, then enter both values in the family's **Calendar connections** tab. The app discovers the account's iCloud calendars over CalDAV, lets the user select one or more calendars, and imports their events in read-only mode.

The app-specific password is stored in the encrypted `access_token` field. Revoking that password in the Apple Account immediately removes the application's CalDAV access.

## Hotwire Native

The web app recognizes both current `Hotwire Native` and legacy `Turbo Native`
user-agent tokens. Native requests keep the same HTML and Turbo behavior while
hiding browser-owned navigation chrome and applying safe-area spacing.

Native clients can load their remote path configuration from:

```text
/hotwire-native/configuration.json
```

Use that URL as the initial path-configuration source in both iOS and Android
shells. The endpoint is public, cacheable for one hour, and provides defaults
for standard navigation, authentication modals, forms, pull-to-refresh, and
screenshots. Add future native navigation behavior to its ordered `rules` list.

## Development

```bash
bin/setup
bin/dev
```

Run the test suite with `bin/rails test`.
