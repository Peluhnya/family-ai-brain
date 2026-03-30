class RemindersController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family

  def create
    @reminder = @family.reminders.new(reminder_params)

    if @reminder.save
      redirect_to family_tab_redirect_path(@family, "reminders"), notice: "Reminder was successfully created."
    else
      prepare_family_page(family: @family, active_tab: "reminders", form_overrides: { reminder_form: @reminder })
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def reminder_params
    params.expect(reminder: %i[title trigger_at channel status])
  end
end
