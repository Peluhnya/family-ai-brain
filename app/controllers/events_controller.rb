class EventsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family
  before_action :set_event, only: %i[update destroy]

  def create
    @event = @family.events.new(event_params)

    if @event.save
      respond_with_family_tab_success(family: @family, active_tab: "events", notice: "Event was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "events", form_overrides: { event_form: @event }, status: :unprocessable_entity)
    end
  end

  def update
    if @event.update(event_params)
      respond_with_family_tab_success(family: @family, active_tab: "events", notice: "Event was successfully updated.")
    else
      render_family_tab_page(family: @family, active_tab: "events", form_overrides: { event_form: @event }, status: :unprocessable_entity)
    end
  end

  def destroy
    @event.destroy!
    respond_with_family_tab_success(family: @family, active_tab: "events", notice: "Event was successfully removed.")
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def event_params
    params.expect(event: %i[title start_time end_time all_day location external_id source])
  end

  def set_event
    @event = @family.events.find(params.expect(:id))
  end
end
