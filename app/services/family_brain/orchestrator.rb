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
      planner = @planner || FamilyBrain::Planner.new(family: @family, user_message: @user_message, now: @now)
      @locale = planner.respond_to?(:response_locale) ? planner.response_locale : nil
      @locale ||= FamilyBrain::LanguageResolver.for_message(family: @family, message: @user_message)
      on_status&.call(status_text(:analysing))
      plan = planner.call

      tool_results = []
      proposal_outcome = nil
      unless plan.failed?
        coordinator = FamilyBrain::ActionProposalCoordinator.new(
          family: @family,
          user_message: @user_message,
          locale: @locale,
          now: @now
        )
        proposal_outcome = coordinator.call(plan.actions, planner_question: plan.clarification_question)
        plan = plan.class.new(
          actions: plan.actions,
          clarification_question: proposal_outcome.clarification_question,
          error: plan.error
        )

        if proposal_outcome.ready_actions.any?
          on_status&.call(status_text(:updating))
          tool_results = FamilyBrain::ToolExecutor.new(
            family: @family,
            user_message: @user_message,
            source_user_text: planner.source_user_text,
            now: @now,
            locale: @locale
          ).call(proposal_outcome.ready_actions.map(&:action))
          proposal_outcome.ready_actions.zip(tool_results).each do |ready_action, result|
            coordinator.complete!(ready_action, result)
          end
        end
      end

      on_status&.call(status_text(:responding))
      FamilyBrain::ResponseFinalizer.new(
        family: @family,
        user: @user,
        user_message: @user_message,
        plan: plan,
        tool_results: tool_results,
        response_locale: @locale
      ).call(&stream_block).merge(
        orchestrator: {
          actions_planned: plan.actions.size,
          tool_results: tool_results.map(&:to_h),
          proposals: Array(proposal_outcome&.pending_proposals).map do |proposal|
            {
              id: proposal.id,
              action_kind: proposal.action_kind,
              state: proposal.state,
              missing_fields: proposal.missing_fields
            }
          end,
          response_locale: @locale,
          clarification_required: plan.clarification_required?,
          planning_error: plan.error
        }
      )
    end

    private

    def status_text(key)
      FamilyBrain::LocaleCatalog.ui_copy(@locale, key)
    end
  end
end
