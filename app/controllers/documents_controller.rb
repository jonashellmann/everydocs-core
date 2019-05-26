class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :update, :destroy]

  # GET /documents
  def index
    @documents = current_user.documents
    json_response(@documents)
  end

  # POST /documents
  def create
    @document = current_user.documents.create!(document_params)
    json_response(@document, :created)
  end

  # GET /documents/:id
  def show
    json_response(@document)
  end

  # PUT /documents/:id
  def update
    @document.update(document_params)
    head :no_content
  end

  # DELETE /documents/:id
  def destroy
    @document.destroy
    head :no_content
  end

  private

  def document_params
    params.permit(:title, :description, :document_date, :document_url, :version, :folder, :user, :state)
  end

  def set_document
    @document = Document.find(params[:id])
  end
end
