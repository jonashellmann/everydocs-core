class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :update, :destroy]

  # GET /documents
  def index
    @documents = current_user.documents
    json_response(@documents)
  end

  # POST /documents
  def create
    @file = params[:document]
    @file_name = (Time.now.to_f * 1000).to_s + '.pdf'
  
    # TODO: Speicherort konfigurierbar machen
    File.open('/var/www/everydocs-files/' + @file_name, 'w+b') {|f| f.write(@file.read)}

    @folder = Folder.find(params[:folder])
    @state = State.find(params[:state])
    
    @params = {
      "title" => params[:title], 
      "description" => params[:description],
      "document_date" => params[:document_date],
      "folder" => @folder,
      "state" => @state,
      "document_url" => @file_name
    }

    @document = current_user.documents.create!(@params)
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
    params.permit(:title, :description, :document_date, :folder, :person, :state, :document)
  end

  def set_document
    @document = Document.find(params[:id])
  end
end
