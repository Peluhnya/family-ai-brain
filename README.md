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

## Development

```bash
bin/setup
bin/dev
```

Run the test suite with `bin/rails test`.
