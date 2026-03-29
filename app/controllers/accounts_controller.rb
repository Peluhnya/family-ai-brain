class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account, only: %i[show edit update destroy]

  def index
    @accounts = current_user.accounts.includes(families: { family_members: :member_users }).order(updated_at: :desc)
  end

  def show
    @families = @account.families.includes(family_members: :member_users).order(:name)
    @family = @account.families.new(timezone: "Europe/Berlin", locale: I18n.locale.to_s)
  end

  def new
    @account = current_user.accounts.new(active: true, email: current_user.email)
  end

  def edit; end

  def create
    @account = current_user.accounts.new(account_params)

    respond_to do |format|
      if @account.save
        format.html { redirect_to @account, notice: "Account was successfully created." }
        format.json { render :show, status: :created, location: @account }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @account.update(account_params)
        format.html { redirect_to @account, notice: "Account was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @account }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @account.destroy!

    respond_to do |format|
      format.html { redirect_to accounts_path, notice: "Account was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_account
    @account = current_user.accounts.find(params.expect(:id))
  end

  def account_params
    params.expect(account: %i[name description email active])
  end
end
