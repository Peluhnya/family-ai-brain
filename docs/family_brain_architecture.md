# Family Brain Architecture

## Target Pipeline

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

## Why This Pipeline

Current architecture already has multiple memory layers and operational entities, but orchestration is still partially spread across controllers and specialized services.

This target pipeline separates:

- structural context vs memory retrieval
- planning vs tool execution
- answer generation vs post-turn memory processing
- short-term online work vs background long-term optimization

## Memory Layers

- `ai_interactions`: short-term conversational memory
- `life_logs`: episodic memory
- `family_knowledge`: semantic memory
- `documents`: RAG layer for long-form reference material
- `events`: calendar layer
- `reminders`: notification layer
- `automation_rules`: procedural memory
- `tasks`: execution layer

## Core Service Objects

The chat action path below is now implemented. A turn is still executed in an
Active Job and streamed with Turbo, but planning and tool execution finish
before the assistant is allowed to confirm a database change.

`ai_effects` is a short-lived execution receipt, not a permanent analytics log.
Successful and skipped effects contain only status, fingerprint, entity link,
and timestamps; their `details` payload remains empty. `PruneAiEffectsJob` runs
daily through Solid Queue and removes completed, skipped, and stale pending
records after 30 days, while failed effects are retained for 90 days. The
cleanup lookup is covered by the `status, created_at` index. Retention windows
and batch size can be configured with
`AI_EFFECT_ROUTINE_RETENTION_DAYS`, `AI_EFFECT_FAILURE_RETENTION_DAYS`, and
`AI_EFFECT_PRUNE_BATCH_SIZE`.

Conversation language handling is independent from business entities. The
current message has priority, recent user messages provide context for short
follow-ups, and `family.locale` is the final fallback. Supported locale packs
are `uk-UA`, `de-DE`, `en-GB`, and `en-US`. `TemporalParser` converts localized
months, weekdays, relative dates, clocks, and ranges into the same ISO 8601
tool contract. Planner output, confirmations, Turbo progress statuses, and
memory extraction use the resolved conversation language. Numeric dates use
the regional order from the locale, so British and American English remain
distinct. The resolved locale is passed through the orchestration pipeline so
the same turn does not repeat language-context database queries.

### 1. `FamilyBrain::Orchestrator`

Single entry point for a chat turn.

Input:

- `family`
- `user`
- `input`
- `channel`

Output:

- assistant response
- tool results
- memory update jobs

### 2. `FamilyBrain::InputNormalizer`

Responsibilities:

- trim and normalize user input
- language hints
- voice transcription normalization
- basic metadata extraction

### 3. `FamilyBrain::IntentDetector`

Responsibilities:

- classify requests
- detect mixed intent
- estimate urgency

Possible intent classes:

- question
- task request
- reminder request
- event request
- document lookup
- family fact update
- mixed intent

### 4. `FamilyBrain::ContextBuilder`

Responsibilities:

- gather account context
- family metadata
- timezone
- members
- integration status
- current UI/channel context

This is structural context, not memory retrieval.

### 5. `FamilyBrain::MemoryRetriever`

Responsibilities:

- retrieve relevant `ai_interactions`
- retrieve relevant `life_logs`
- retrieve relevant `family_knowledge`
- retrieve relevant `documents`
- include active `tasks`, `events`, `reminders`
- include active `automation_rules`

This should sit above `FamilyBrain::RetrievalService`.

### 6. `FamilyBrain::Planner`

Responsibilities:

- decide whether tools are needed
- choose one or multiple tools
- prepare tool arguments
- decide whether response is answer-only, tool-only, or mixed

This is where tool selection belongs.

### 7. `FamilyBrain::ChatService`

Responsibilities:

- execute RubyLLM call
- receive already prepared prompt/context
- not own orchestration decisions

### 8. `FamilyBrain::ToolExecutor`

Responsibilities:

- unified execution facade for:
  - create task
  - create event
  - create reminder
  - create life log
  - create family knowledge
  - future integrations

`AutomationExecutionService` should eventually delegate here.

### 9. `FamilyBrain::ResponseFinalizer`

Responsibilities:

- build final user-facing response
- merge tool outputs into natural response
- keep output concise and practical
- apply language/style rules

## Memory Processor

This is critical and should be explicit.

### `FamilyBrain::MemoryProcessor`

Responsibilities:

- analyze dialog turns
- create `life_logs`
- update `family_knowledge`
- create follow-up memory artifacts
- compress old conversation context

### Recommended sub-services

- `FamilyBrain::LifeLogExtractor`
- `FamilyBrain::KnowledgeSyncService`
- `FamilyBrain::TaskSyncService`
- `FamilyBrain::EventSyncService`
- `FamilyBrain::ReminderSyncService`
- `FamilyBrain::ConversationCompressor`

`MemoryProcessor` should orchestrate these instead of embedding everything into one service.

## Long-Term Memory Optimization

This should exist as a separate background layer.

### Goals

- avoid overloading LLM context
- preserve important information
- compress low-value repetition
- keep retrieval quality high over time

### Optimization tools

- embeddings via `pgvector`
- summaries
- importance score
- time decay

### Recommended services

- `FamilyBrain::LongTermMemoryOptimizer`
- `FamilyBrain::ImportanceScorer`
- `FamilyBrain::TimeDecayService`
- `FamilyBrain::MemorySummarizer`
- `FamilyBrain::EmbeddingBackfillService`
- `FamilyBrain::MemoryPruner`

### Design notes

- time decay should affect retrieval ranking, not blindly destroy records
- pruning should target only low-importance and redundant data
- summaries should be stored as derived memory artifacts
- embeddings should be backfilled for any record that matters in retrieval

## What Should Stay In Controllers

Controllers should remain thin.

For example `AiInteractionsController#create` should only:

- validate access
- persist user message
- call `FamilyBrain::Orchestrator`
- redirect or render

Controllers should not directly own:

- memory extraction
- reminder/task/event sync logic
- orchestration decisions
- prompt assembly decisions

## What Should Move To Background Jobs

### Synchronous

- input normalization
- intent detection
- context building
- memory retrieval
- planning
- LLM response generation
- tool execution when user expects immediate result

### Background

- `MemoryProcessingJob`
- `LongTermMemoryOptimizationJob`
- `DocumentEmbeddingJob`
- `CalendarSyncJob`
- `ReminderDeliveryJob`
- `RunDueRemindersJob`
- `AutomationRuleExecutionJob`

## Recommended Service Tree

```text
app/services/family_brain/
  orchestrator.rb
  input_normalizer.rb
  intent_detector.rb
  context_builder.rb
  memory_retriever.rb
  planner.rb
  tool_executor.rb
  response_finalizer.rb

  chat_service.rb
  prompt_builder.rb
  retrieval_service.rb
  embedding_service.rb

  memory_processor.rb
  life_log_extractor.rb
  knowledge_sync_service.rb
  task_sync_service.rb
  event_sync_service.rb
  reminder_sync_service.rb
  conversation_compressor.rb

  long_term_memory_optimizer.rb
  importance_scorer.rb
  time_decay_service.rb
  memory_summarizer.rb
  embedding_backfill_service.rb
  memory_pruner.rb
```

## Existing Services That Already Fit

- `FamilyBrain::Orchestrator`
- `FamilyBrain::Planner`
- `FamilyBrain::ActionPolicy`
- `FamilyBrain::ToolExecutor`
- `FamilyBrain::ResponseFinalizer`
- `FamilyBrain::ChatService`
- `FamilyBrain::PromptBuilder`
- `FamilyBrain::RetrievalService`
- `FamilyBrain::MemoryProcessor`
- `FamilyBrain::LifeLogSyncService`
- `FamilyBrain::KnowledgeSyncService`

The legacy task/event/reminder sync services remain for compatibility, but the
chat path now uses the unified planner and tool executor.

## Recommended Next Implementation Steps

Completed:

1. Introduce `FamilyBrain::Orchestrator`
2. Run planner and tool execution in the asynchronous chat job
3. Introduce `MemoryProcessingJob`
4. Add `FamilyBrain::MemoryProcessor`
5. Separate operational actions from post-turn memory extraction

Still pending:

1. Add `LongTermMemoryOptimizationJob`
2. Add scoring, summaries, and decay as independent services
