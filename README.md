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

## Development

```bash
bin/setup
bin/dev
```

Run the test suite with `bin/rails test`.
