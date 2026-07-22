module FamilyBrain
  class Orchestrator
    def initialize(family:, user:, user_message:, planner: nil, now: Time.current)
      @family = family
      @user = user
      @user_message = user_message
      @now = now
      @planner = planner
    end

    def call(on_status: nil, &stream_block)
      on_status&.call("Аналізую запит…")
      planner = @planner || FamilyBrain::Planner.new(family: @family, user_message: @user_message, now: @now)
      plan = planner.call

      tool_results = []
      unless plan.failed?
        on_status&.call("Оновлюю сімейний простір…") if plan.actions.any?
        tool_results = FamilyBrain::ToolExecutor.new(
          family: @family,
          user_message: @user_message,
          source_user_text: planner.source_user_text,
          now: @now
        ).call(plan.actions)
      end

      on_status&.call("Формую відповідь…")
      FamilyBrain::ResponseFinalizer.new(
        family: @family,
        user: @user,
        user_message: @user_message,
        plan: plan,
        tool_results: tool_results
      ).call(&stream_block).merge(
        orchestrator: {
          actions_planned: plan.actions.size,
          tool_results: tool_results.map(&:to_h),
          clarification_required: plan.clarification_required?,
          planning_error: plan.error
        }
      )
    end
  end
end
