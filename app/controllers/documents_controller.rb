class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :download, :update, :destroy]
  before_action :set_documents, only: [:index, :page_count]

  # GET /documents
  def index
    @start_index = 0
    if (!params[:page].blank?)
      @start_index = (convert_to_int(params[:page]) - 1) * 20
    end
    @end_index = @start_index + 19
    @documents = @documents[@start_index..@end_index]

    json_response(@documents)
  end

  # POST /documents
  def create
    @file = params[:document]
    @file_text = ""
    @encrypted = current_user.encryption_actived_flag? and current_user.secret_key.present?

    if @file.blank?
      @file_name = nil
    else
      @file_name = SecureRandom.uuid + '.pdf'

      if @encrypted
        lockbox = Lockbox.new(key: current_user.secret_key)

        data = @file.read
        encrypted_data = lockbox.encrypt(data)
        File.write(Settings.document_folder + @file_name, encrypted_data, mode: 'w+b')
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
    @document_count = @documents.length()
    @page_count = (@document_count/20.to_f).ceil
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
  end
end
