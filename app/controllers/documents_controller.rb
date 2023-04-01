class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :download, :update, :destroy]

  # GET /documents
  def index
    @documents = current_user.documents.order(document_date: :desc)

    if (!params[:folder_filter].blank?)
      @documents = @documents.select { |d| d.folder_id == convert_to_int(params[:folder_filter])}
    end
    if (!params[:state_filter].blank?)
      @documents = @documents.select { |d| d.state_id == convert_to_int(params[:state_filter])}
    end
    if (!params[:person_filter].blank?)
      @documents = @documents.select { |d| d.person_id == convert_to_int(params[:person_filter])}
    end
    if (!params[:search].blank?)
      @search = params[:search].to_s.downcase.delete(' ')
      @documents = @documents.select { |d| (d.title.downcase.delete(' ').include?(@search) or (!d.description.nil? and d.description.downcase.delete(' ').include?(@search)) or (!d.document_text.nil? and d.document_text.downcase.delete(' ').include?(@search)))}
    end

    json_response(@documents)
  end

  # POST /documents
  def create
    @file = params[:document]
    @file_text = ""

    if @file.blank?
      @file_name = nil
    else
      @file_name = SecureRandom.uuid + '.pdf'
      File.open(Settings.document_folder + @file_name, 'w+b') {|f| f.write(@file.read)}

      begin
        reader = PDF::Reader.new(Settings.document_folder + @file_name)
        reader.pages.each do |page|
          @file_text = @file_text + page.text
        end

        @file_text.delete!("\r\n")
        @file_text.delete!("\n")
        @file_text.delete!(' ')

        if @file_text.bytesize > 65535
          @file_text = ""
        end

        rescue PDF::Reader::MalformedPDFError
          @file_text = ""
        end
    end

    @folder = params[:folder].blank? ? nil : Folder.find(params[:folder])
    @state = params[:state].blank? ? nil : State.find(params[:state])
    @person = params[:person].blank? ? nil : Person.find(params[:person])

    @params = {
      "title" => params[:title], 
      "description" => params[:description],
      "document_date" => params[:document_date],
      "document_text" => @file_text,
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
    send_file Settings.document_folder + @document.document_url, :filename=>@document.title + ".pdf", :type=>"application/pdf", :x_sendfile=>true, :disposition => 'attachment'
  end

  # PUT /documents/:id
  def update
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
    }

    @document.update(@params)
    head :no_content
  end

  # DELETE /documents/:id
  def destroy
    @filename = Settings.document_folder + @document.document_url
    File.delete(@filename) if File.exist?(@filename)
    
    @document.destroy
    head :no_content
  end

  private

  def convert_to_int(string)
    num = string.to_i
    num if num.to_s == string
  end

  def set_document
    @document = Document.find(params[:id])
  end
end
