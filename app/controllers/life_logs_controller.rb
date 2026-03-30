class LifeLogsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family

  def create
    @life_log = @family.life_logs.new(life_log_params)
    @life_log.embedding = FamilyBrain::EmbeddingService.embed([@life_log.event_type, @life_log.summary, @life_log.raw_text].compact.join("\n"), account: @family.account)

    if @life_log.save
      FamilyBrain::KnowledgeSyncService.new(
        family: @family,
        text: [@life_log.summary, @life_log.raw_text].compact.join("\n"),
        source: "life_log:auto"
      ).call

      redirect_to family_tab_redirect_path(@family, "logs"), notice: "Life log was successfully created."
    else
      prepare_family_page(family: @family, active_tab: "logs", form_overrides: { life_log_form: @life_log })
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def life_log_params
    params.expect(life_log: %i[event_type summary raw_text importance happened_at])
  end
end
