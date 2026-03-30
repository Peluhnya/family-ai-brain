module FamilyBrain
  class TaskSyncService
    TASK_SCHEMA = {
      type: "object",
      properties: {
        tasks: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string" },
              evidence: { type: "string" },
              description: { type: "string" },
              assignee_name: { type: "string" },
              priority: { type: "integer" },
              due_in_days: { type: "integer" }
            },
            required: %w[title evidence description assignee_name priority due_in_days],
            additionalProperties: false
          }
        }
      },
      required: ["tasks"],
      additionalProperties: false
    }.freeze

    def initialize(family:, text:)
      @family = family
      @text = text.to_s.strip
    end

    def call
      return [] if @text.blank?
      llm_client = FamilyBrain::LlmClient.new(account: @family.account)
      return [] unless llm_client.available?

      response = llm_client.with_chat(schema: TASK_SCHEMA) do |chat|
        chat.ask(extraction_prompt)
      end
      payload = response.content.is_a?(Hash) ? response.content : {}

      Array(payload["tasks"]).filter_map { |task_payload| create_task(task_payload) }
    rescue StandardError
      []
    end

    private

    def extraction_prompt
      <<~PROMPT
        Extract only explicit actionable family tasks directly requested or described by the user.
        Ignore vague ideas, completed actions, assistant-style summaries, and general discussion.
        Do not invent tasks from context. If the user did not clearly ask for a task or describe a concrete todo, return an empty list.
        For each task, include an evidence field with the exact short quote from the user's text that proves this task exists.
        Return up to 3 tasks.
        Use Ukrainian for title and description.
        If there is no clear assignee from family members, set assignee_name to an empty string.
        priority must be an integer from 1 to 5 where 5 is highest.
        due_in_days must be 0 if no clear deadline is mentioned.

        Family members:
        #{family_members_block}

        Text:
        #{@text}
      PROMPT
    end

    def family_members_block
      return "- no members" if @family.family_members.empty?

      @family.family_members.order(:name).map { |member| "- #{member.name}" }.join("\n")
    end

    def create_task(task_payload)
      title = task_payload["title"].to_s.strip
      evidence = task_payload["evidence"].to_s.strip
      return if title.blank?
      return unless FamilyBrain::GroundedExtraction.meaningful_phrase?(title)
      return unless FamilyBrain::GroundedExtraction.evidence_present?(@text, evidence)
      return unless FamilyBrain::GroundedExtraction.title_grounded_in_evidence?(title, evidence)
      return if duplicate_open_task?(title)

      @family.tasks.create!(
        title: title,
        description: task_payload["description"].to_s.strip.presence,
        assigned_to: resolve_assignee_id(task_payload["assignee_name"]),
        due_at: normalize_due_at(task_payload["due_in_days"]),
        status: "pending",
        priority: normalize_priority(task_payload["priority"])
      )
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def duplicate_open_task?(title)
      @family.tasks.active.where(title: title).exists?
    end

    def resolve_assignee_id(assignee_name)
      name = assignee_name.to_s.strip.downcase
      return if name.blank?

      @family.family_members.order(:name).detect { |member| member.name.to_s.strip.downcase == name }&.id
    end

    def normalize_priority(value)
      value.to_i.clamp(1, 5)
    end

    def normalize_due_at(value)
      days = value.to_i
      return if days <= 0

      days.days.from_now
    end

  end
end
