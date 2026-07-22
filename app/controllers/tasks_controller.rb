class TasksController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family
  before_action :set_task, only: %i[update destroy]

  def create
    @task = @family.tasks.new(task_params)

    if @task.save
      respond_with_family_tab_success(family: @family, active_tab: "tasks", notice: "Task was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "tasks", form_overrides: { task_form: @task }, status: :unprocessable_entity)
    end
  end

  def update
    if @task.update(task_params)
      respond_with_family_tab_success(family: @family, active_tab: "tasks", notice: "Task was successfully updated.")
    else
      render_family_tab_page(family: @family, active_tab: "tasks", form_overrides: { task_form: @task }, status: :unprocessable_entity)
    end
  end

  def destroy
    @task.destroy!
    respond_with_family_tab_success(family: @family, active_tab: "tasks", notice: "Task was successfully removed.")
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def task_params
    params.expect(task: %i[title description assigned_to due_at status priority])
  end

  def set_task
    @task = @family.tasks.find(params.expect(:id))
  end
end
