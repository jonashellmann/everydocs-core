require 'test_helper'

class DocumentsControllerTest < ActionController::TestCase
  setup do
    @non_encrypted_user = users(:one)
    @encrypted_user = users(:two)
    
    @work_folder = folders(:work)
    @personal_folder = folders(:personal)
    @draft_state = states(:draft)
    @review_state = states(:review)
    @john_person = people(:john)
    @jane_person = people(:jane)
    
    @token_without_encryption = JsonWebToken.encode(user_id: @non_encrypted_user.id)
    @token_with_encryption = JsonWebToken.encode(user_id: @encrypted_user.id)
    
    @test_pdf_content = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>\nendobj\n4 0 obj\n<< /Length 44 >>\nstream\nBT\n/F1 24 Tf\n100 700 Td\n(Hello World) Tj\nET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000208 00000 n \ntrailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n310\n%%EOF"
  end

  # ==================== Create Tests ====================
  
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

  test "should return 422 when document is not provided" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    assert_no_difference('Document.count') do
      post :create, params: {
        title: 'Empty Document',
        description: 'Document without file',
        document_date: Date.today.to_s
      }
    end
    
    assert_response :unprocessable_entity
    
    json_response = JSON.parse(@response.body)
    assert_includes json_response['message'], 'required'
  end

  test "should return 422 when document file is empty" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    temp_file = Tempfile.new(['empty', '.pdf'])
    temp_file.write('')
    temp_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/pdf')
    
    assert_no_difference('Document.count') do
      post :create, params: {
        document: uploaded_file,
        title: 'Empty File Document',
        description: 'Empty file',
        document_date: Date.today.to_s
      }
    end
    
    assert_response :unprocessable_entity
    
    json_response = JSON.parse(@response.body)
    assert_includes json_response['message'], 'empty'
    
    temp_file.close
    temp_file.unlink
  end

  test "should return 422 when document is not a PDF" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    temp_file = Tempfile.new(['test', '.txt'])
    temp_file.write('This is a text file, not a PDF')
    temp_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, 'text/plain')
    
    assert_no_difference('Document.count') do
      post :create, params: {
        document: uploaded_file,
        title: 'Text Document',
        description: 'This is not a PDF',
        document_date: Date.today.to_s
      }
    end
    
    assert_response :unprocessable_entity
    
    json_response = JSON.parse(@response.body)
    assert_includes json_response['message'], 'PDF'
    
    temp_file.close
    temp_file.unlink
  end

  test "non-encrypted document should have document_text extracted" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    temp_file = Tempfile.new(['test', '.pdf'])
    temp_file.write(@test_pdf_content)
    temp_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/pdf')
    
    assert_difference('Document.count') do
      post :create, params: {
        document: uploaded_file,
        title: 'Document With Text',
        description: 'Test text extraction',
        document_date: Date.today.to_s
      }
    end
    
    assert_response :created
    
    new_document = Document.last
    assert_equal false, new_document.encrypted_flag
    assert_not_empty new_document.document_text
    
    File.delete(Settings.document_folder + new_document.document_url) if File.exist?(Settings.document_folder + new_document.document_url)
    temp_file.close
    temp_file.unlink
  end

  test "encrypted document should have empty document_text" do
    @request.headers['Authorization'] = "Bearer #{@token_with_encryption}"
    
    temp_file = Tempfile.new(['test', '.pdf'])
    temp_file.write(@test_pdf_content)
    temp_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/pdf')
    
    assert_difference('Document.count') do
      post :create, params: {
        document: uploaded_file,
        title: 'Encrypted Document With Text',
        description: 'Encrypted, text should be empty',
        document_date: Date.today.to_s
      }
    end
    
    assert_response :created
    
    new_document = Document.last
    assert_equal true, new_document.encrypted_flag
    assert_empty new_document.document_text
    
    File.delete(Settings.document_folder + new_document.document_url) if File.exist?(Settings.document_folder + new_document.document_url)
    temp_file.close
    temp_file.unlink
  end

  # ==================== Download Tests ====================

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

  # ==================== Filter Tests (ActiveRecord Queries) ====================

  test "should filter documents by folder" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { folder_filter: @work_folder.id }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 2, documents.length
    
    titles = documents.map { |d| d['title'] }
    assert_includes titles, 'Work Report 2024'
    assert_includes titles, 'Project Proposal'
    assert_not_includes titles, 'Personal Notes'
  end

  test "should filter documents by state" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { state_filter: @draft_state.id }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 2, documents.length
    
    titles = documents.map { |d| d['title'] }
    assert_includes titles, 'Work Report 2024'
    assert_includes titles, 'Personal Notes'
    assert_not_includes titles, 'Project Proposal'
  end

  test "should filter documents by folder and state" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { 
      folder_filter: @work_folder.id,
      state_filter: @draft_state.id
    }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 1, documents.length
    assert_equal 'Work Report 2024', documents.first['title']
  end

  test "invalid filter ID should be ignored" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { folder_filter: 'abc' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 3, documents.length
  end

  test "negative filter ID should be ignored" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { folder_filter: '-1' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 3, documents.length
  end

  test "zero filter ID should be ignored" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { folder_filter: '0' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 3, documents.length
  end

  # ==================== Search Tests (ActiveRecord Queries) ====================

  test "should search documents by title" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { search: 'Work Report' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 1, documents.length
    assert_equal 'Work Report 2024', documents.first['title']
  end

  test "should search documents by description" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { search: 'personal document' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 1, documents.length
    assert_equal 'Personal Notes', documents.first['title']
  end

  test "should search documents by document_text" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { search: 'projectproposalq1' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 1, documents.length
    assert_equal 'Project Proposal', documents.first['title']
  end

  test "search should ignore spaces" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { search: 'Project  Proposal  Q1' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 1, documents.length
    assert_equal 'Project Proposal', documents.first['title']
  end

  test "search should be case insensitive" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { search: 'work report' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 1, documents.length
    assert_equal 'Work Report 2024', documents.first['title']
  end

  test "search with no matches should return empty array" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { search: 'nonexistentkeyword123456' }
    
    assert_response :success
    
    documents = JSON.parse(@response.body)
    
    assert_equal 0, documents.length
  end

  # ==================== Pagination Tests (Unified Logic) ====================

  test "pagination should work correctly with filtered results" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    25.times do |i|
      Document.create!(
        title: "Pagination Test #{i + 1}",
        document_date: Date.today - i.days,
        document_url: "page_test_#{i}.pdf",
        user: @non_encrypted_user,
        encrypted_flag: false,
        folder: @work_folder
      )
    end
    
    get :index, params: { folder_filter: @work_folder.id, page: 1 }
    
    assert_response :success
    page1 = JSON.parse(@response.body)
    assert_equal 20, page1.length
    
    get :index, params: { folder_filter: @work_folder.id, page: 2 }
    
    assert_response :success
    page2 = JSON.parse(@response.body)
    assert_equal 5, page2.length
    
    Document.where(folder_id: @work_folder.id).where('title LIKE ?', 'Pagination Test%').destroy_all
  end

  test "page_count should reflect filtered results" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    25.times do |i|
      Document.create!(
        title: "Page Count Test #{i + 1}",
        document_date: Date.today - i.days,
        document_url: "count_test_#{i}.pdf",
        user: @non_encrypted_user,
        encrypted_flag: false,
        folder: @work_folder
      )
    end
    
    get :page_count, params: { folder_filter: @work_folder.id }
    
    assert_response :success
    result = JSON.parse(@response.body)
    
    assert_equal 2, result['page_count']
    
    Document.where(folder_id: @work_folder.id).where('title LIKE ?', 'Page Count Test%').destroy_all
  end

  test "no page param should default to page 1" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    3.times do |i|
      Document.create!(
        title: "Default Page Test #{i + 1}",
        document_date: Date.today - i.days,
        document_url: "default_test_#{i}.pdf",
        user: @non_encrypted_user,
        encrypted_flag: false
      )
    end
    
    get :index
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_equal 6, documents.length
    
    Document.where('title LIKE ?', 'Default Page Test%').destroy_all
  end

  test "page 0 should default to page 1" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { page: 0 }
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_not_empty documents
  end

  test "page 0 as string should default to page 1" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { page: '0' }
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_not_empty documents
  end

  test "negative page should default to page 1" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { page: -1 }
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_not_empty documents
  end

  test "negative page as string should default to page 1" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { page: '-5' }
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_not_empty documents
  end

  test "non-numeric page should default to page 1" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { page: 'abc' }
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_not_empty documents
  end

  test "page with decimal should default to page 1" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { page: '1.5' }
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_not_empty documents
  end

  test "page with special chars should default to page 1" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index, params: { page: '1abc' }
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_not_empty documents
  end

  test "page beyond total pages should return empty array" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    5.times do |i|
      Document.create!(
        title: "Beyond Test #{i + 1}",
        document_date: Date.today - i.days,
        document_url: "beyond_test_#{i}.pdf",
        user: @non_encrypted_user,
        encrypted_flag: false
      )
    end
    
    get :index, params: { page: 100 }
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    assert_equal 0, documents.length
    
    Document.where('title LIKE ?', 'Beyond Test%').destroy_all
  end

  test "page_count with invalid page should still return correct count" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    5.times do |i|
      Document.create!(
        title: "Count Invalid Test #{i + 1}",
        document_date: Date.today - i.days,
        document_url: "count_invalid_test_#{i}.pdf",
        user: @non_encrypted_user,
        encrypted_flag: false
      )
    end
    
    get :page_count, params: { page: 'invalid' }
    
    assert_response :success
    result = JSON.parse(@response.body)
    
    assert_equal 1, result['page_count']
    
    Document.where('title LIKE ?', 'Count Invalid Test%').destroy_all
  end

  test "index and page_count should use same query logic with filters" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    10.times do |i|
      Document.create!(
        title: "Consistency Test #{i + 1}",
        document_date: Date.today - i.days,
        document_url: "consistency_test_#{i}.pdf",
        user: @non_encrypted_user,
        encrypted_flag: false,
        folder: @work_folder
      )
    end
    
    get :page_count, params: { folder_filter: @work_folder.id }
    page_count_result = JSON.parse(@response.body)
    total_pages = page_count_result['page_count']
    
    get :index, params: { folder_filter: @work_folder.id, page: 1 }
    index_result = JSON.parse(@response.body)
    
    assert_equal 1, total_pages
    assert_equal 12, index_result.length
    
    Document.where(folder_id: @work_folder.id).where('title LIKE ?', 'Consistency Test%').destroy_all
  end

  # ==================== Security Tests ====================

  test "should return unauthorized without token" do
    post :create, params: {
      title: 'Test',
      document_date: Date.today.to_s
    }
    
    assert_response :unauthorized
  end

  test "should return unauthorized for index without token" do
    get :index
    
    assert_response :unauthorized
  end

  test "should return unauthorized for page_count without token" do
    get :page_count
    
    assert_response :unauthorized
  end

  test "user should only see own documents" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    user_ids = documents.map { |d| d['user']['id'] }.uniq
    assert_equal [@non_encrypted_user.id], user_ids
    assert_not_includes documents.map { |d| d['title'] }, 'Encrypted Invoice'
  end

  # ==================== Order Tests ====================

  test "documents should be ordered by document_date descending" do
    @request.headers['Authorization'] = "Bearer #{@token_without_encryption}"
    
    get :index
    
    assert_response :success
    documents = JSON.parse(@response.body)
    
    dates = documents.map { |d| Date.parse(d['document_date']) }
    assert_equal dates.sort.reverse, dates
  end
end
