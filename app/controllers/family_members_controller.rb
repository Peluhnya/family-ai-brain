class FamilyMembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family, only: :create
  before_action :set_family_member, only: %i[edit update destroy]
  before_action :prepare_member_form_data, only: :edit

  def create
    @family_member = @family.family_members.new(family_member_params)

    if attach_user_to_member(@family_member) && @family_member.save
      redirect_to family_path(@family), notice: "Family member was successfully created."
    else
      prepare_family_show_state(@family_member)
      render "families/show", status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @family = @family_member.family

    if @family_member.update(family_member_params) && replace_member_link(@family_member)
      redirect_to family_path(@family), notice: "Family member was successfully updated."
    else
      prepare_member_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    family = @family_member.family
    @family_member.destroy!

    redirect_to family_path(family), notice: "Family member was successfully removed.", status: :see_other
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def set_family_member
    @family_member = FamilyMember.joins(family: :account)
      .where(accounts: { user_id: current_user.id })
      .find(params.expect(:id))
  end

  def family_member_params
    params.expect(family_member: %i[name role birthdate]).merge(permissions: parsed_permissions)
  end

  def parsed_permissions
    raw_permissions = params.dig(:family_member, :permissions_text).to_s

    return nil if raw_permissions.blank?

    raw_permissions.split(",").map(&:strip).reject(&:blank?)
  end

  def attach_user_to_member(member)
    linked_user = resolve_linked_user(member)
    return false if member.errors.any?

    member.member_users.build(user: linked_user, role: member.role.presence || "member") if linked_user
    true
  end

  def replace_member_link(member)
    linked_user = resolve_linked_user(member)
    return false if member.errors.any?

    member.member_users.destroy_all
    member.member_users.create!(user: linked_user, role: member.role.presence || "member") if linked_user
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def resolve_linked_user(member)
    selected_user_id = params.dig(:family_member, :linked_user_id).presence
    new_user_email = params.dig(:family_member, :new_user_email).to_s.strip.downcase

    if selected_user_id.present? && new_user_email.present?
      member.errors.add(:base, "Choose an existing user or provide a new user email, not both.")
      return nil
    end

    if selected_user_id.present?
      linked_user = available_users_for(member.family.account).find_by(id: selected_user_id)
      member.errors.add(:base, "Selected user is not available for this account.") unless linked_user
      return linked_user
    end

    return if new_user_email.blank?

    existing_user = User.find_by(email: new_user_email)
    return existing_user if existing_user

    generated_password = SecureRandom.base58(24)
    created_user = User.new(email: new_user_email, password: generated_password, password_confirmation: generated_password)

    unless created_user.save
      created_user.errors.full_messages.each { |message| member.errors.add(:base, message) }
      return nil
    end

    created_user
  end

  def prepare_family_show_state(family_member)
    @family = family_member.family
    @family_member_form = family_member
    @families = @family.account.families.includes(family_members: :member_users)
    @available_users = available_users_for(@family.account)
    @ai_interactions = @family.ai_interactions.includes(:user).order(:created_at)
    @ai_interaction = @family.ai_interactions.new
    @life_logs = @family.life_logs.priority_first.limit(8)
    @life_log_form = @family.life_logs.new(happened_at: Time.current, importance: 0.7, event_type: "routine")
    @family_knowledge_items = @family.family_knowledge.priority_first.limit(8)
    @family_knowledge_form = @family.family_knowledge.new(confidence: 0.8, source: "manual")
    @documents = @family.documents.recent_first.limit(10)
    @document_form = @family.documents.new
    @events = @family.events.upcoming_first.limit(10)
    @event_form = @family.events.new(
      start_time: Time.current.change(min: 0) + 1.hour,
      end_time: Time.current.change(min: 0) + 2.hours,
      source: "manual"
    )
    @calendar_connections = @family.calendar_connections.active_first.limit(10)
    @calendar_connection_form = @family.calendar_connections.new(provider: "google_calendar", active: true)
    @reminders = @family.reminders.upcoming_first.limit(10)
    @reminder_form = @family.reminders.new(trigger_at: Time.current.change(min: 0) + 1.hour, channel: "app", status: "pending")
    @tasks = @family.tasks.open_first.limit(10)
    @task_form = @family.tasks.new(status: "pending", priority: 3)
    @automation_rules = @family.automation_rules.active_first.limit(8)
    @automation_rule_form = @family.automation_rules.new(active: true, template_key: "daily_ai_note")
  end

  def prepare_member_form_data
    @available_users = available_users_for(@family_member.family.account)
  end

  def available_users_for(account)
    linked_ids = account.families.joins(family_members: :member_users).distinct.pluck("member_users.user_id")
    User.where(id: linked_ids + [current_user.id]).or(User.where(email: current_user.email)).order(:email)
  end
end
