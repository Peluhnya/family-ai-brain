class TasksController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family

  def create
    @task = @family.tasks.new(task_params)

    if @task.save
      redirect_to family_tab_redirect_path(@family, "tasks"), notice: "Task was successfully created."
    else
      prepare_family_page(family: @family, active_tab: "tasks", form_overrides: { task_form: @task })
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def task_params
    params.expect(task: %i[title description assigned_to due_at status priority])
  end
end
