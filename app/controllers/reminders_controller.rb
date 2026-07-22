class RemindersController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family
  before_action :set_reminder, only: %i[update destroy]

  def create
    @reminder = @family.reminders.new(reminder_params)

    if @reminder.save
      respond_with_family_tab_success(family: @family, active_tab: "reminders", notice: "Reminder was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "reminders", form_overrides: { reminder_form: @reminder }, status: :unprocessable_entity)
    end
  end

  def update
    if @reminder.update(reminder_params)
      respond_with_family_tab_success(family: @family, active_tab: "reminders", notice: "Reminder was successfully updated.")
    else
      render_family_tab_page(family: @family, active_tab: "reminders", form_overrides: { reminder_form: @reminder }, status: :unprocessable_entity)
    end
  end

  def destroy
    @reminder.destroy!
    respond_with_family_tab_success(family: @family, active_tab: "reminders", notice: "Reminder was successfully removed.")
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def reminder_params
    params.expect(reminder: %i[title trigger_at channel status])
  end

  def set_reminder
    @reminder = @family.reminders.find(params.expect(:id))
  end
end
