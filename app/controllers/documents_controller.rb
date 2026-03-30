class DocumentsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family

  def create
    @document = @family.documents.new(document_params)
    @document.embedding = FamilyBrain::EmbeddingService.embed([@document.title, @document.content].compact.join("\n\n"), account: @family.account)

    if @document.save
      redirect_to family_tab_redirect_path(@family, "documents"), notice: "Document was successfully created."
    else
      prepare_family_page(family: @family, active_tab: "documents", form_overrides: { document_form: @document })
      render "families/show", status: :unprocessable_entity
    end
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def document_params
    params.expect(document: %i[title content])
  end
end
