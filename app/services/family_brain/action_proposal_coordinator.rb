require "digest"

module FamilyBrain
  class ActionProposalCoordinator
    ReadyAction = Data.define(:action, :proposal)
    Outcome = Data.define(:ready_actions, :pending_proposals, :clarification_question)

    EXPIRATION = 24.hours

    def initialize(family:, user_message:, locale:, now: Time.current, policy: FamilyBrain::ActionDecisionPolicy.new)
      @family = family
      @user_message = user_message
      @conversation = user_message.conversation
      @locale = FamilyBrain::LocaleCatalog.normalize(locale) || FamilyBrain::LocaleCatalog::DEFAULT_LOCALE
      @now = now
      @policy = policy
    end

    def call(actions, planner_question: "")
      ready_actions = []
      pending_proposals = []

      Array(actions).each do |raw_action|
        action = apply_server_guards(raw_action.to_h.deep_stringify_keys)
        decision = @policy.call(action)
        proposal = persist_proposal(action, decision)

        if decision.state == "ready"
          ready_actions << ReadyAction.new(action: executable_action(action), proposal: proposal)
        else
          pending_proposals << proposal
        end
      end

      Outcome.new(
        ready_actions: ready_actions,
        pending_proposals: pending_proposals,
        clarification_question: pending_question(pending_proposals, planner_question)
      )
    end

    def complete!(ready_action, result)
      proposal = ready_action.proposal
      proposal.update!(
        state: result.status == "failed" ? "failed" : "completed",
        entity_type: result.entity_type,
        entity_id: result.entity_id,
        executed_at: @now,
        error_message: result.status == "failed" ? result.message : nil
      )
      broadcast(proposal)
    end

    private

    def persist_proposal(action, decision)
      proposal = active_referenced_proposal(action["proposal_id"]) || new_proposal(action)
      proposal.assign_attributes(
        confirmation_ai_interaction: proposal.persisted? ? @user_message : nil,
        action_kind: action.fetch("kind"),
        state: decision.state,
        intent_strength: decision.intent_strength,
        risk: decision.risk,
        action_fingerprint: fingerprint(action),
        missing_fields: decision.missing_fields,
        expires_at: decision.state == "ready" ? nil : @now + EXPIRATION,
        error_message: nil
      )
      proposal.payload_data = executable_action(action)
      proposal.evidence_data = Array(action["evidence"]).map do |quote|
        evidence_item_for(quote, action_kind: action["kind"])
      end
      proposal.save!
      broadcast(proposal) if proposal.confirmation_ai_interaction_id.present?
      proposal
    rescue ActiveRecord::RecordNotUnique
      @family.ai_action_proposals.find_by!(
        source_ai_interaction: @user_message,
        action_fingerprint: fingerprint(action)
      )
    end

    def new_proposal(action)
      @family.ai_action_proposals.new(
        conversation: @conversation,
        source_ai_interaction: @user_message,
        action_kind: action.fetch("kind"),
        action_fingerprint: fingerprint(action)
      )
    end

    def active_referenced_proposal(value)
      proposal_id = value.to_i
      return if proposal_id <= 0

      proposal = @family.ai_action_proposals.awaiting_input.find_by(id: proposal_id, conversation: @conversation)
      return unless proposal

      if proposal.expired?(@now)
        proposal.update!(state: "expired")
        return
      end

      proposal
    end

    def executable_action(action)
      action.except("proposal_id", "intent_strength", "ambiguities")
    end

    def fingerprint(action)
      normalized = executable_action(action).sort.to_h.merge(
        "evidence" => Array(action["evidence"]).map(&:to_s).sort
      )
      Digest::SHA256.hexdigest(normalized.to_json)
    end

    def pending_question(proposals, planner_question)
      return planner_question.to_s.strip if planner_question.present?
      return "" if proposals.empty?

      if proposals.any? { |proposal| proposal.state == "awaiting_clarification" }
        FamilyBrain::LocaleCatalog.proposal_copy(@locale, :clarification_needed)
      else
        FamilyBrain::LocaleCatalog.proposal_copy(@locale, :confirmation_needed)
      end
    end

    def apply_server_guards(action)
      action["ambiguities"] = Array(action["ambiguities"]).map(&:to_s)
      validate_update_target!(action)
      validate_assignee!(action)
      validate_future_time!(action)
      validate_automation!(action)
      validate_evidence_sources!(action)
      action
    end

    def validate_update_target!(action)
      model = {
        "update_task" => @family.tasks,
        "update_reminder" => @family.reminders,
        "update_event" => @family.events,
        "update_knowledge" => @family.family_knowledge,
        "update_life_log" => @family.life_logs,
        "update_document" => @family.documents,
        "update_automation_rule" => @family.automation_rules
      }[action["kind"]]
      return unless model

      record = model.find_by(id: action["record_id"])
      unless record
        action["ambiguities"] << "record_id"
        return
      end

      return unless action["kind"] == "update_event"
      return if (record.source_key.presence || record.source).in?(%w[manual ai_chat])

      action["ambiguities"] << "external_event_read_only"
    end

    def validate_assignee!(action)
      return unless action["kind"].in?(%w[create_task update_task])

      name = action["assignee_name"].to_s
      return if name.blank?

      normalized = FamilyBrain::GroundedExtraction.normalize_text(name)
      matched = @family.family_members.any? do |member|
        FamilyBrain::GroundedExtraction.normalize_text(member.name) == normalized
      end
      action["ambiguities"] << "assignee_name" unless matched
    end

    def validate_future_time!(action)
      field = case action["kind"]
      when "create_reminder" then "trigger_at"
      when "create_event" then "start_at"
      when "create_life_log" then "happened_at"
      end
      return unless field && action[field].present?

      parsed = Time.iso8601(action[field].to_s)
      if action["kind"] == "create_life_log"
        action["ambiguities"] << "#{field}_in_future" if parsed > @now + 5.minutes
      else
        action["ambiguities"] << "#{field}_in_past" if parsed < @now
      end
    rescue ArgumentError
      action["ambiguities"] << field
    end

    def validate_automation!(action)
      return unless action["kind"].in?(%w[create_automation_rule update_automation_rule])

      trigger_types = %w[schedule_daily schedule_weekly schedule_monthly chat_keyword]
      action_types = %w[create_ai_note create_life_log create_family_knowledge create_task create_event create_reminder]
      changed_fields = Array(action["changed_fields"])
      validate_trigger = action["kind"] == "create_automation_rule" || changed_fields.any? do |field|
        field.start_with?("automation_trigger_") || field == "automation_match_mode"
      end
      validate_action = action["kind"] == "create_automation_rule" || changed_fields.any? do |field|
        field.start_with?("automation_action_") || field.in?(%w[key value confidence event_type importance])
      end

      action["ambiguities"] << "automation_trigger_type" if validate_trigger && !action["automation_trigger_type"].in?(trigger_types)
      action["ambiguities"] << "automation_action_type" if validate_action && !action["automation_action_type"].in?(action_types)

      if action["automation_trigger_time"].present? && !action["automation_trigger_time"].match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
        action["ambiguities"] << "automation_trigger_time"
      end
      if action["automation_trigger_weekday"].present? && !action["automation_trigger_weekday"].in?(%w[monday tuesday wednesday thursday friday saturday sunday])
        action["ambiguities"] << "automation_trigger_weekday"
      end
      if action["automation_trigger_day"].to_i.positive? && !action["automation_trigger_day"].to_i.between?(1, 31)
        action["ambiguities"] << "automation_trigger_day"
      end
      if action["automation_match_mode"].present? && !action["automation_match_mode"].in?(%w[exact_command word contains])
        action["ambiguities"] << "automation_match_mode"
      end
    end

    def validate_evidence_sources!(action)
      quotes = Array(action["evidence"]).map(&:to_s).reject(&:blank?)
      return if quotes.empty?

      allowed_roles = action["kind"].in?(%w[create_document update_document]) ? %w[user assistant] : [ "user" ]
      messages = @conversation.ai_interactions
        .where(role: allowed_roles)
        .where("id <= ?", @user_message.id)
        .order(id: :desc)
        .limit(20)
        .to_a
      user_messages = messages.select { |message| message.role == "user" }

      unverified = quotes.any? do |quote|
        messages.none? { |message| FamilyBrain::GroundedExtraction.evidence_fragment_present?(message.content, quote) }
      end
      has_full_user_evidence = quotes.any? do |quote|
        user_messages.any? { |message| FamilyBrain::GroundedExtraction.evidence_present?(message.content, quote) }
      end
      action["ambiguities"] << "evidence" if unverified || !has_full_user_evidence
    end

    def evidence_item_for(quote, action_kind:)
      quote = quote.to_s
      allowed_roles = action_kind.in?(%w[create_document update_document]) ? %w[user assistant] : [ "user" ]
      source = @conversation.ai_interactions
        .where(role: allowed_roles)
        .where("id <= ?", @user_message.id)
        .order(id: :desc)
        .limit(20)
        .detect { |message| FamilyBrain::GroundedExtraction.evidence_fragment_present?(message.content, quote) }

      {
          "source_type" => "AiInteraction",
          "source_id" => source&.id || @user_message.id,
          "source_role" => source&.role || "user",
          "quote" => quote
      }
    end

    def broadcast(proposal)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ proposal.family, :ai_chat ],
        target: ActionView::RecordIdentifier.dom_id(proposal),
        partial: "ai_action_proposals/proposal",
        locals: { proposal: proposal }
      )
    end
  end
end
