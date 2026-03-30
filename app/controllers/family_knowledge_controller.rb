class FamilyKnowledgeController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family

  def create
    @knowledge = @family.family_knowledge.new(family_knowledge_params)
    @knowledge.embedding = FamilyBrain::EmbeddingService.embed([@knowledge.key, @knowledge.value].compact.join(": "), account: @family.account)

    if @knowledge.save
      redirect_to family_tab_redirect_path(@family, "knowledge"), notice: "Family knowledge was successfully created."
    else
      prepare_family_page(family: @family, active_tab: "knowledge", form_overrides: { family_knowledge_form: @knowledge })
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def family_knowledge_params
    params.expect(family_knowledge: %i[key value source confidence])
  end
end
