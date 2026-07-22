class FamilyKnowledgeController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family
  before_action :set_knowledge, only: %i[update destroy]

  def create
    @knowledge = @family.family_knowledge.new(family_knowledge_params)
    @knowledge.embedding = FamilyBrain::EmbeddingService.embed([@knowledge.key, @knowledge.value].compact.join(": "), account: @family.account)

    if @knowledge.save
      respond_with_family_tab_success(family: @family, active_tab: "knowledge", notice: "Family knowledge was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "knowledge", form_overrides: { family_knowledge_form: @knowledge }, status: :unprocessable_entity)
    end
  end

  def update
    @knowledge.assign_attributes(family_knowledge_params)
    @knowledge.embedding = FamilyBrain::EmbeddingService.embed([@knowledge.key, @knowledge.value].compact.join(": "), account: @family.account)

    if @knowledge.save
      respond_with_family_tab_success(family: @family, active_tab: "knowledge", notice: "Family knowledge was successfully updated.")
    else
      render_family_tab_page(family: @family, active_tab: "knowledge", form_overrides: { family_knowledge_form: @knowledge }, status: :unprocessable_entity)
    end
  end

  def destroy
    @knowledge.destroy!
    respond_with_family_tab_success(family: @family, active_tab: "knowledge", notice: "Family knowledge was successfully removed.")
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def family_knowledge_params
    params.expect(family_knowledge: %i[key value source confidence])
  end

  def set_knowledge
    @knowledge = @family.family_knowledge.find(params.expect(:id))
  end
end
