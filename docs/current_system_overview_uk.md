# Family AI Brain: Поточна документація системи

## Що це за продукт

`Family AI Brain` це AI-first система для керування сімейним життям.

Головна ідея:

- зібрати в одному місці `memory + automation + context + execution`
- дати сім’ї один shared `AI brain`
- не просто відповідати в чаті, а зберігати памʼять, будувати контекст і виконувати дії

Поточний фокус системи:

- `family desk`
- `chat with LLM`
- `memory system`
- `automation rules`
- `tasks / events / reminders`
- `documents for RAG`
- `calendar sync foundation + Google Calendar integration`

## Основна структура продукту

### `Account`

`Account` це окремий workspace / context.

Приклади:

- `Personal`
- `Work`
- `Parents`
- `Wife family`

Один користувач може мати кілька `accounts`.

### `Family`

Усередині `account` живуть `families`.

`Family` це основна операційна одиниця, для якої:

- ведеться чат
- зберігається памʼять
- створюються `tasks`
- ведуться `events`
- працюють `reminders`
- запускаються `automation_rules`

### `FamilyMember`

Усередині `family` живуть `family_members`.

`FamilyMember` може:

- існувати просто як запис члена сімʼї
- бути linked до існуючого `User`
- створювати нового `User` через email

## Поточні memory layers

### 1. `ai_interactions`

`Short-term memory`

Зберігає:

- user messages
- assistant replies
- модель
- tokens

Використовується для:

- conversational continuity
- recent context in prompt

### 2. `life_logs`

`Episodic memory`

Зберігає:

- `event_type`
- `summary`
- `raw_text`
- `importance`
- `embedding`
- `happened_at`

Використовується для:

- життєвих подій
- рутин
- звичок
- історії того, що відбувалось

### 3. `family_knowledge`

`Semantic memory`

Зберігає:

- `key`
- `value`
- `source`
- `confidence`
- `embedding`

Використовується для:

- стабільних фактів
- правил
- вподобань
- повторюваних знань про сімʼю

### 4. `documents`

`RAG layer`

Зберігає:

- `title`
- `content`
- `embedding`

Використовується для:

- long-form notes
- policies
- school documents
- medical notes
- reference knowledge

### 5. `automation_rules`

`Procedural memory`

Зберігає:

- що робити
- коли робити
- які правила активні

### 6. `events`

`Calendar layer`

Зберігає:

- назву події
- час початку/кінця
- локацію
- source / external id для sync

### 7. `reminders`

`Notification layer`

Зберігає:

- що потрібно нагадати
- коли нагадати
- яким каналом
- delivery status

### 8. `tasks`

`Execution layer`

Зберігає:

- title
- description
- assignee
- due date
- status
- priority

## Family Desk

Головний робочий екран сімʼї це `family show`, який зараз працює як `family desk`.

На ньому є:

- `AI conversation`
- `Memory architecture`
- `Calendar connections`
- `Documents`
- `Reminders`
- `Events`
- `Tasks`
- `Automation rules`
- `Family knowledge`
- `Life logs`
- `Family members`

Більшість блоків мають вкладки:

- `Список`
- `Новий`

Тобто в межах одного блоку можна:

- переглянути поточні дані
- одразу створити новий запис

## LLM / AI шар

### `RubyLLM`

LLM integration побудована через `RubyLLM`.

Поточні можливості:

- family chat
- embeddings
- structured extraction через `with_schema`

### Account-level AI configuration

На рівні `Account` можна:

- використовувати `app default AI`
- або підключити власний `OpenAI API key`

Також підтримується:

- `openai`
- `openai_compatible`

AI settings зберігаються encrypted.

## Поточний chat flow

Коли користувач надсилає повідомлення:

1. створюється `user ai_interaction`
2. асинхронний `GenerateAiAssistantReplyJob` запускає `FamilyBrain::Orchestrator`
3. `Planner` аналізує поточну репліку разом із коротким контекстом діалогу
4. `ActionPolicy` додає обов’язкові companion actions, наприклад reminder до deadline task
5. `ToolExecutor` створює або оновлює `tasks`, `events`, `reminders`
6. кожен результат записується в `ai_effects`
7. лише після фактичного виконання `ResponseFinalizer` генерує підтверджену відповідь
8. статус і відповідь стрімляться через Turbo
9. окремий `MemoryProcessingJob` запускає episodic/semantic memory processing

Operational planning зараз включає:

- `Planner`
- `ActionPolicy`
- `ToolExecutor`
- `ResponseFinalizer`

Memory post-processing включає:

- `LifeLogSyncService`
- `KnowledgeSyncService`

Контракт пам’яті:

- майбутні відпустки, табори, подорожі та зустрічі — `events`
- завершені важливі переживання і моменти — `life_logs`
- сталі вподобання, правила та довготривалі факти — `family_knowledge`
- одна календарна подія не дублюється автоматично в semantic knowledge

## Prompt building

Поточний `PromptBuilder` формує prompt з:

- account context
- family members
- relevant `life_logs`
- relevant `family_knowledge`
- relevant `documents`
- upcoming `events`
- active `reminders`
- active `automation_rules`
- active `tasks`

Це дає LLM:

- short-term conversational context
- semantic context
- episodic context
- RAG context
- operational context

## Retrieval

`RetrievalService` використовує:

- `pgvector`
- `neighbor`
- `EmbeddingService`

Поточний vector retrieval є для:

- `family_knowledge`
- `life_logs`
- `documents`

Fallback behavior:

- якщо embeddings недоступні або query embedding не згенерувався,
  система використовує fallback scopes (`priority_first`, `recent_first`)

## Automation system

### `automation_rules`

Automation rules мають:

- `trigger_type`
- `trigger_config`
- `action_type`
- `action_config`
- `template_key`
- `active`
- `last_executed_at`

### Trigger types

Підтримуються:

- `schedule_daily`
- `schedule_weekly`
- `schedule_monthly`
- `chat_keyword`

### Action types

Підтримуються:

- `create_ai_note`
- `create_life_log`
- `create_family_knowledge`
- `create_task`
- `create_event`
- `create_reminder`

### Visual Rule Builder

Є `visual rule builder`, який дозволяє створювати rules без ручного JSON.

Поточні templates включають:

- daily / weekly AI note
- monthly life log
- chat keyword -> knowledge
- daily / keyword task
- daily / keyword event
- daily / keyword reminder

## Recurring jobs

Через `recurring.yml` зараз автоматично запускаються:

- `RunDueAutomationRulesJob`
- `RunDueRemindersJob`

Це означає:

- due automation rules виконуються автоматично
- due reminders теж обробляються автоматично

Для локальної розробки треба запускати:

```bash
bin/dev
```

Бо потрібні:

- `web`
- `css`
- `jobs`

## Reminders execution layer

Для reminders вже є delivery pipeline:

- `ReminderSchedulerService`
- `RunDueRemindersJob`
- `ReminderDeliveryJob`
- `ReminderDeliveryService`

Поточна поведінка:

- due `pending` reminders ставляться в queue
- після delivery reminder переходить у `sent`

Поточна delivery implementation поки базова:

- `app` -> запис в `ai_interactions`
- `email` -> stub запис
- `sms` -> stub запис

Тобто lifecycle уже є, але реальні email/sms integrations ще не підключені.

## Calendar sync

### `events`

Для synced events існують:

- `source`
- `source_key`
- `external_id`
- `sync_fingerprint`

Це дає:

- dedupe
- upsert
- нормальний sync flow

### `calendar_connections`

Є окрема модель `calendar_connections`.

Вона зберігає:

- provider
- remote calendar id
- encrypted tokens
- sync cursor
- settings
- last synced at
- last error

### Google Calendar

Перший реальний provider уже реалізований:

- Google OAuth
- access token / refresh token exchange
- `calendarList.list`
- вибір конкретного Google calendar
- `events.list`
- incremental sync через `syncToken`

Flow:

1. створити `google_calendar` connection
2. натиснути `Authorize Google`
3. пройти OAuth
4. перейти в `Select calendar`
5. вибрати конкретний calendar
6. натиснути `Sync now`

## Privacy / Encryption

У системі використовується:

- `ActiveRecord::Encryption`

Encryption застосовується до чутливих текстових полів.

Важливе правило:

- не всі типи колонок можна безпечно шифрувати напряму
- наприклад `date/datetime/integer/vector/jsonb` не треба blindly encrypt-ити в typed column

Тому encrypted зберігаються переважно:

- `text`
- `string`

А operational fields, потрібні для:

- filters
- sorting
- foreign keys
- scheduling
- vector search

здебільшого лишаються unencrypted

## Поточна high-level architecture

Цільова схема зафіксована окремо тут:

- [family_brain_architecture.md](./family_brain_architecture.md)

Коротко:

```text
User input
↓
Input normalization
↓
Intent detection
↓
Context builder
↓
Memory retrieval
↓
Planner
↓
LLM
↓
Tool execution
↓
Final response
↓
Memory processor
↓
Long-term memory optimization
```

## Що вже зроблено добре

- family/account/member hierarchy
- encrypted AI settings
- working family desk
- short-term / episodic / semantic / procedural / RAG layers
- tasks / events / reminders / documents
- recurring automation execution
- recurring reminder delivery
- Google Calendar OAuth + calendar selection + sync foundation

## Що ще лишається великим наступним кроком

### 1. `Long-term memory optimization`

Потрібно реалізувати:

- `summaries`
- `importance score`
- `time decay`
- compression / pruning policies

### 2. Real delivery integrations

Для `reminders` ще немає реальних:

- email delivery
- sms delivery
- push/app notifications

### 5. Richer external integrations

Майбутнє:

- Apple Calendar real sync
- Outlook real sync
- banks
- weather
- email
- document ingestion from files

## Важливі operational команди

### Development

```bash
bin/dev
```

### Tailwind build

```bash
bin/rails tailwindcss:build
```

### Autoload check

```bash
bin/rails zeitwerk:check
```

### Migrations

```bash
bin/rails db:migrate
```

## Підсумок

На поточний момент система вже не є просто chat UI.

Вона вже має:

- memory layers
- RAG documents
- automation engine
- operational entities
- recurring jobs
- integration foundation

Тобто база для справжнього `Family AI Brain` уже побудована.
