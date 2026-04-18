require 'test_helper'

class DocumentsControllerTest < ActionController::TestCase
  setup do
    @non_encrypted_user = users(:one)
    @encrypted_user = users(:two)
    @document = documents(:one)
    
    @token_without_encryption = JsonWebToken.encode(user_id: @non_encrypted_user.id)
    @token_with_encryption = JsonWebToken.encode(user_id: @encrypted_user.id)
    
    @test_pdf_content = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n192\n%%EOF"
  end

  test "should create document without encryption for non-encrypted user" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    temp_file = Tempfile.new(['test', '.pdf'])
    temp_file.write(@test_pdf_content)
    temp_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/pdf')
    
    assert_difference('Document.count') do
      post :create, params: {
        document: uploaded_file,
        title: 'Test Document',
        description: 'Test description',
        document_date: Date.today.to_s
      }
    end
    
    assert_response :created
    
    new_document = Document.last
    assert_equal false, new_document.encrypted_flag
    assert_equal 'Test Document', new_document.title
    
    assert File.exist?(Settings.document_folder + new_document.document_url)
    
    stored_content = File.read(Settings.document_folder + new_document.document_url)
    assert_equal @test_pdf_content, stored_content
    
    File.delete(Settings.document_folder + new_document.document_url) if File.exist?(Settings.document_folder + new_document.document_url)
    temp_file.close
    temp_file.unlink
  end

  test "should create document with encryption for encrypted user" do
    @request.headers['Authorization'] = "Bearer #{@token_with_encryption}"
    
    temp_file = Tempfile.new(['test', '.pdf'])
    temp_file.write(@test_pdf_content)
    temp_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/pdf')
    
    assert_difference('Document.count') do
      post :create, params: {
        document: uploaded_file,
        title: 'Encrypted Test Document',
        description: 'Encrypted test description',
        document_date: Date.today.to_s
      }
    end
    
    assert_response :created
    
    new_document = Document.last
    assert_equal true, new_document.encrypted_flag
    assert_equal 'Encrypted Test Document', new_document.title
    
    assert File.exist?(Settings.document_folder + new_document.document_url)
    
    stored_content = File.read(Settings.document_folder + new_document.document_url)
    assert_not_equal @test_pdf_content, stored_content
    
    lockbox = Lockbox.new(key: @encrypted_user.secret_key)
    decrypted_content = lockbox.decrypt(stored_content)
    assert_equal @test_pdf_content, decrypted_content
    
    File.delete(Settings.document_folder + new_document.document_url) if File.exist?(Settings.document_folder + new_document.document_url)
    temp_file.close
    temp_file.unlink
  end

  test "should create document without file (empty document)" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    assert_difference('Document.count') do
      post :create, params: {
        title: 'Empty Document',
        description: 'Document without file',
        document_date: Date.today.to_s
      }
    end
    
    assert_response :created
    
    new_document = Document.last
    assert_equal 'Empty Document', new_document.title
    assert_nil new_document.document_url
    assert_equal false, new_document.encrypted_flag
  end

  test "should download non-encrypted document" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    document = Document.create!(
      title: 'Download Test',
      document_date: Date.today,
      document_url: 'download_test.pdf',
      user: @non_encrypted_user,
      encrypted_flag: false
    )
    
    File.write(Settings.document_folder + 'download_test.pdf', @test_pdf_content, mode: 'w+b')
    
    get :download, params: { id: document.id }
    
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
    assert_equal @test_pdf_content, @response.body
    
    File.delete(Settings.document_folder + 'download_test.pdf') if File.exist?(Settings.document_folder + 'download_test.pdf')
    document.destroy
  end

  test "should download and decrypt encrypted document" do
    @request.headers['Authorization'] = "Bearer #{@token_with_encryption}"
    
    lockbox = Lockbox.new(key: @encrypted_user.secret_key)
    encrypted_content = lockbox.encrypt(@test_pdf_content)
    
    document = Document.create!(
      title: 'Encrypted Download Test',
      document_date: Date.today,
      document_url: 'encrypted_download_test.pdf',
      user: @encrypted_user,
      encrypted_flag: true
    )
    
    File.write(Settings.document_folder + 'encrypted_download_test.pdf', encrypted_content, mode: 'w+b')
    
    get :download, params: { id: document.id }
    
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
    assert_equal @test_pdf_content, @response.body
    
    File.delete(Settings.document_folder + 'encrypted_download_test.pdf') if File.exist?(Settings.document_folder + 'encrypted_download_test.pdf')
    document.destroy
  end

  test "should return unauthorized without token" do
    post :create, params: {
      title: 'Test',
      document_date: Date.today.to_s
    }
    
    assert_response :unauthorized
  end
end
