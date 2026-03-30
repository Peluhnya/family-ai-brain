class EventsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family

  def create
    @event = @family.events.new(event_params)

    if @event.save
      redirect_to family_tab_redirect_path(@family, "events"), notice: "Event was successfully created."
    else
      prepare_family_page(family: @family, active_tab: "events", form_overrides: { event_form: @event })
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def event_params
    params.expect(event: %i[title start_time end_time location external_id source])
  end
end
