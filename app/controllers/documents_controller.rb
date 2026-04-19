class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :download, :update, :destroy]
  before_action :set_documents, only: [:index, :page_count]

  # GET /documents
  def index
    page = params[:page].blank? ? 1 : convert_to_int(params[:page])
    page = 1 if page.nil? || page < 1
    
    @documents = @documents.offset((page - 1) * 20).limit(20)

    json_response(@documents)
  end

  # POST /documents
  def create
    @file = params[:document]
    @file_text = ""
    @encrypted = current_user.encryption_actived_flag? and current_user.secret_key.present?

    if @file.blank?
      json_response({ message: "Document file is required" }, :unprocessable_entity)
      return
    end

    data = @file.read
    if data.nil? || data.empty?
      json_response({ message: "Document file cannot be empty" }, :unprocessable_entity)
      return
    end

    content_type = @file.content_type.to_s
    original_filename = @file.original_filename.to_s
    is_pdf = content_type == 'application/pdf' || 
             content_type == 'application/octet-stream' ||
             original_filename.end_with?('.pdf')

    unless is_pdf
      json_response({ message: "Only PDF documents are allowed" }, :unprocessable_entity)
      return
    end

    @file_name = SecureRandom.uuid + '.pdf'

    if @encrypted
      lockbox = Lockbox.new(key: current_user.secret_key)
      encrypted_data = lockbox.encrypt(data)
      File.write(Settings.document_folder + @file_name, encrypted_data, mode: 'w+b')
      @file_text = ""
    else
      File.write(Settings.document_folder + @file_name, data, mode: 'w+b')

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
      rescue PDF::Reader::MalformedPDFError, PDF::Reader::EncryptedPDFError
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
      "document_url" => @file_name,
      "encrypted_flag" => @encrypted
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
    if @document.encrypted_flag
      lockbox = Lockbox.new(key: current_user.secret_key)
      decrypted_data = lockbox.decrypt(File.read(Settings.document_folder + @document.document_url))
      send_data decrypted_data, :filename=>@document.title + ".pdf", :type=>"application/pdf", :x_sendfile=>true, :disposition=>'attachement'
    else
      send_file Settings.document_folder + @document.document_url, :filename=>@document.title + ".pdf", :type=>"application/pdf", :x_sendfile=>true, :disposition=>'attachment' 
    end
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

  # GET /documents/pages
  def page_count
    @document_count = @documents.count
    @page_count = (@document_count / 20.0).ceil
    json_response(page_count: @page_count)
  end

  private

  def convert_to_int(string)
    num = string.to_i
    num if num.to_s == string
  end

  def set_document
    @document = Document.find(params[:id])
  end

  def set_documents
    @documents = current_user.documents.order(document_date: :desc)

    folder_id = convert_to_int(params[:folder_filter]) if !params[:folder_filter].blank?
    state_id = convert_to_int(params[:state_filter]) if !params[:state_filter].blank?
    person_id = convert_to_int(params[:person_filter]) if !params[:person_filter].blank?

    @documents = @documents.where(folder_id: folder_id) if folder_id
    @documents = @documents.where(state_id: state_id) if state_id
    @documents = @documents.where(person_id: person_id) if person_id

    if !params[:search].blank?
      search_term = params[:search].to_s.downcase.delete(' ')
      
      if search_term.present?
        search_pattern = "%#{search_term}%"
        
        @documents = @documents.where(
          "LOWER(REPLACE(title, ' ', '')) LIKE :search OR 
           (LOWER(REPLACE(description, ' ', '')) LIKE :search AND description IS NOT NULL) OR 
           (LOWER(REPLACE(document_text, ' ', '')) LIKE :search AND document_text IS NOT NULL)",
          search: search_pattern
        )
      end
    end
  end
end
