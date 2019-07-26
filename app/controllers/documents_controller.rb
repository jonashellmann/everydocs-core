class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :download, :update, :destroy]
  skip_before_action :authorize_request, only: :download

  # GET /documents
  def index
    @documents = current_user.documents
    json_response(@documents)
  end

  # POST /documents
  def create
    @file = params[:document]
    
    if @file.blank?
      @file_name = nil
    else
      @file_name = SecureRandom.uuid + '.pdf'
      File.open('/var/www/html/everydocs-web/files/' + @file_name, 'w+b') {|f| f.write(@file.read)}
    end

    @folder = params[:folder].blank? ? nil : Folder.find(params[:folder])
    @state = params[:state].blank? ? nil : State.find(params[:state])
    @person = params[:person].blank? ? nil : Person.find(params[:person])

    @params = {
      "title" => params[:title], 
      "description" => params[:description],
      "document_date" => params[:document_date],
      "folder" => @folder,
      "state" => @state,
      "person" => @person,
      "document_url" => @file_name
    }

    @document = current_user.documents.create!(@params)
    json_response(@document, :created)
  end

  # GET /documents/:id
  def show
    json_response(@document)
  end

  # GET /documents/file/:id
  def download
    send_file '/var/www/html/everydocs-web/files/' + @document.document_url, :type=>"application/pdf", :x_sendfile=>true
  end

  # PUT /documents/:id
  def update
    @folder = Folder.find(params[:folder])
    @state = State.find(params[:state])
    @person = Person.find(params[:person])

    @params = {
      "title" => params[:title],
      "description" => params[:description],
      "document_date" => params[:document_date],
      "folder" => @folder,
      "state" => @state,
      "person" => @person,
    }

    @document.update(@params)
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
