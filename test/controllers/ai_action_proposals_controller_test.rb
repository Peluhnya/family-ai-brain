require "test_helper"

class AiActionProposalsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
    @family = families(:one)
    @conversation = Conversation.for_family_at!(family: @family)
    @message = @family.ai_interactions.create!(
      conversation: @conversation,
      role: "user",
      content: "У пʼятницю прийом у лікаря",
      user: @user,
      model: "human"
    )
    @proposal = proposal(state: "awaiting_confirmation")
    sign_in @user
  end

  test "confirms and queues an inferred proposal" do
    assert_enqueued_with(job: ExecuteAiActionProposalJob, args: [ @proposal.id ]) do
      post confirm_family_ai_action_proposal_path(@family, @proposal), as: :turbo_stream
    end

    assert_response :success
    assert_equal "ready", @proposal.reload.state
    assert_equal @user, @proposal.confirmed_by
  end

  test "rejects an active proposal without executing it" do
    assert_no_enqueued_jobs only: ExecuteAiActionProposalJob do
      post reject_family_ai_action_proposal_path(@family, @proposal), as: :turbo_stream
    end

    assert_response :success
    assert_equal "rejected", @proposal.reload.state
  end

  test "expires an old proposal instead of executing it" do
    @proposal.update!(expires_at: 1.minute.ago)

    assert_no_enqueued_jobs only: ExecuteAiActionProposalJob do
      post confirm_family_ai_action_proposal_path(@family, @proposal), as: :turbo_stream
    end

    assert_response :success
    assert_equal "expired", @proposal.reload.state
  end

  private

  def proposal(state:)
    record = @family.ai_action_proposals.new(
      conversation: @conversation,
      source_ai_interaction: @message,
      action_kind: "create_event",
      action_fingerprint: SecureRandom.hex,
      state: state,
      intent_strength: "inferred",
      risk: "low",
      expires_at: 1.day.from_now
    )
    record.payload_data = {
      kind: "create_event",
      record_id: 0,
      title: "Прийом у лікаря",
      description: "",
      assignee_name: "",
      priority: 3,
      due_at: "",
      trigger_at: "",
      channel: "app",
      start_at: 2.days.from_now.iso8601,
      end_at: "",
      all_day: false,
      location: "",
      evidence: [ @message.content ],
      changed_fields: []
    }
    record.evidence_data = [ { source_type: "AiInteraction", source_id: @message.id, quote: @message.content } ]
    record.save!
    record
  end
end
