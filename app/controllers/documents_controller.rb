class DocumentsController < ApplicationController
  include FamilyPageContext

  before_action :authenticate_user!
  before_action :set_family
  before_action :set_document, only: %i[update destroy]

  def create
    @document = @family.documents.new(document_params)
    @document.embedding = FamilyBrain::EmbeddingService.embed([@document.title, @document.content].compact.join("\n\n"), account: @family.account)

    if @document.save
      respond_with_family_tab_success(family: @family, active_tab: "documents", notice: "Document was successfully created.")
    else
      render_family_tab_page(family: @family, active_tab: "documents", form_overrides: { document_form: @document }, status: :unprocessable_entity)
    end
  end

  def update
    @document.assign_attributes(document_params)
    @document.embedding = FamilyBrain::EmbeddingService.embed([@document.title, @document.content].compact.join("\n\n"), account: @family.account)

    if @document.save
      respond_with_family_tab_success(family: @family, active_tab: "documents", notice: "Document was successfully updated.")
    else
      render_family_tab_page(family: @family, active_tab: "documents", form_overrides: { document_form: @document }, status: :unprocessable_entity)
    end
  end

  def destroy
    @document.destroy!
    respond_with_family_tab_success(family: @family, active_tab: "documents", notice: "Document was successfully removed.")
  end

  private

  def set_family
    @family = Family.joins(:account).where(accounts: { user_id: current_user.id }).find(params.expect(:family_id))
  end

  def document_params
    params.expect(document: %i[title content])
  end

  def set_document
    @document = @family.documents.find(params.expect(:id))
  end
end
