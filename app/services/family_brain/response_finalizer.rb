module FamilyBrain
  class ResponseFinalizer
    def initialize(family:, user:, user_message:, plan:, tool_results:)
      @family = family
      @user = user
      @user_message = user_message
      @plan = plan
      @tool_results = tool_results
    end

    def call(&block)
      return clarification_response if only_clarification?

      response = FamilyBrain::ChatService.new(
        family: @family,
        user: @user,
        message: @user_message,
        turn_execution_context: execution_context
      ).call(&block)

      return response unless response[:model] == "local-fallback" && @tool_results.any?

      response.merge(content: deterministic_result_summary)
    end

    private

    def only_clarification?
      @plan.clarification_required? && @tool_results.empty? && !@plan.failed?
    end

    def clarification_response
      {
        content: @plan.clarification_question,
        model: "action-planner",
        tokens: nil,
        input_tokens: nil,
        output_tokens: nil,
        prompt_version: "orchestrator_v1",
        usage_metadata: {
          tool_results: [],
          clarification_required: true
        }
      }
    end

    def execution_context
      <<~CONTEXT
        TURN EXECUTION RESULTS (authoritative)
        #{tool_results_block}

        FINAL RESPONSE RULES
        - Describe an action as completed only when its status is created, updated, skipped because it already exists, or already_completed.
        - Never claim that a failed action succeeded.
        - Do not promise to create something later; the results above are the complete outcome of this turn.
        - If an action failed, say briefly that it was not saved.
        - If a clarification question is provided below, ask it after summarizing any successful actions.
        - Do not expose internal ids, planner terminology, schemas or implementation details.
        - Keep the answer concise and in Ukrainian.

        CLARIFICATION QUESTION
        #{@plan.clarification_question.presence || 'none'}

        PLANNING STATUS
        #{@plan.failed? ? "Planning failed; no unlisted changes were made: #{@plan.error}" : 'completed'}
      CONTEXT
    end

    def tool_results_block
      return "- no database changes" if @tool_results.empty?

      @tool_results.map do |result|
        "- #{result.kind}: status=#{result.status}; entity=#{result.entity_type || 'none'}; title=#{result.title}; note=#{result.message}"
      end.join("\n")
    end

    def deterministic_result_summary
      lines = @tool_results.map do |result|
        case result.status
        when "created" then "Створено: #{result.title}."
        when "updated" then "Оновлено: #{result.title}."
        when "skipped", "already_completed" then "Вже існує: #{result.title}."
        else "Не вдалося зберегти: #{result.title}."
        end
      end
      lines << @plan.clarification_question if @plan.clarification_required?
      lines.join("\n")
    end
  end
end
