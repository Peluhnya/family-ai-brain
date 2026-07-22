class LifeLogsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family
  before_action :set_life_log, only: %i[update destroy]

  def create
    @life_log = @family.life_logs.new(life_log_params)
    @life_log.embedding = FamilyBrain::EmbeddingService.embed([ @life_log.event_type, @life_log.summary, @life_log.raw_text ].compact.join("\n"), account: @family.account)

    if @life_log.save
      respond_with_family_tab_success(family: @family, active_tab: "logs", notice: "Life log was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "logs", form_overrides: { life_log_form: @life_log }, status: :unprocessable_entity)
    end
  end

  def update
    @life_log.assign_attributes(life_log_params)
    @life_log.embedding = FamilyBrain::EmbeddingService.embed([ @life_log.event_type, @life_log.summary, @life_log.raw_text ].compact.join("\n"), account: @family.account)

    if @life_log.save
      respond_with_family_tab_success(family: @family, active_tab: "logs", notice: "Life log was successfully updated.")
    else
      render_family_tab_page(family: @family, active_tab: "logs", form_overrides: { life_log_form: @life_log }, status: :unprocessable_entity)
    end
  end

  def destroy
    @life_log.destroy!
    respond_with_family_tab_success(family: @family, active_tab: "logs", notice: "Life log was successfully removed.")
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def life_log_params
    params.expect(life_log: %i[event_type summary raw_text importance happened_at])
  end

  def set_life_log
    @life_log = @family.life_logs.find(params.expect(:id))
  end
end
