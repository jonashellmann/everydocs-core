require 'test_helper'
require 'tempfile'

class ImportsControllerTest < ActionController::TestCase
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    request.headers['Authorization'] = "Bearer #{@token}"

    @valid_export_data = {
      schema_version: 1,
      exported_at: Time.current.iso8601,
      user: {
        name: 'Test User',
        email: 'test@example.com'
      },
      data: {
        folders: [
          { name: 'Imported Work', parent_folder_name: nil, created_at: 1.day.ago.iso8601, updated_at: 1.day.ago.iso8601 },
          { name: 'Imported Sub', parent_folder_name: 'Imported Work', created_at: 1.day.ago.iso8601, updated_at: 1.day.ago.iso8601 }
        ],
        tags: [
          { name: 'Imported Tag', color: '#ff0000', created_at: 1.day.ago.iso8601, updated_at: 1.day.ago.iso8601 }
        ],
        people: [
          { name: 'Imported Person', created_at: 1.day.ago.iso8601, updated_at: 1.day.ago.iso8601 }
        ],
        states: [
          { name: 'Imported State', created_at: 1.day.ago.iso8601, updated_at: 1.day.ago.iso8601 }
        ],
        documents: [
          {
            title: 'Imported Document',
            description: 'Test import',
            document_date: Date.today.iso8601,
            version: '1.0',
            encrypted_flag: false,
            folder_name: 'Imported Work',
            state_name: 'Imported State',
            person_name: 'Imported Person',
            tag_names: ['Imported Tag'],
            document_text: 'searchable content here',
            created_at: 1.day.ago.iso8601,
            updated_at: 1.day.ago.iso8601
          }
        ]
      }
    }

    @encrypted_export_data = {
      schema_version: 1,
      exported_at: Time.current.iso8601,
      user: {
        name: 'Encrypted User',
        email: 'encrypted@example.com'
      },
      data: {
        folders: [
          { name: 'Encrypted Folder', parent_folder_name: nil, created_at: 1.day.ago.iso8601, updated_at: 1.day.ago.iso8601 }
        ],
        tags: [],
        people: [],
        states: [],
        documents: [
          {
            title: 'Encrypted Import',
            description: 'Confidential',
            document_date: Date.today.iso8601,
            version: '1.0',
            encrypted_flag: true,
            folder_name: 'Encrypted Folder',
            state_name: nil,
            person_name: nil,
            tag_names: [],
            created_at: 1.day.ago.iso8601,
            updated_at: 1.day.ago.iso8601
          }
        ]
      }
    }

    @unsupported_version_data = {
      schema_version: 999,
      exported_at: Time.current.iso8601,
      user: { name: 'Test', email: 'test@test.com' },
      data: {
        folders: [],
        tags: [],
        people: [],
        states: [],
        documents: []
      }
    }
  end

  test 'should preview import data without modifying database' do
    post :preview, params: { import: @valid_export_data }, format: :json

    assert_response :success
    json_response = JSON.parse(response.body)

    assert json_response['success']
    assert json_response['dry_run']

    preview = json_response['preview']
    assert_equal 1, preview['schema_version']
    assert_equal 2, preview['data_counts']['folders']
    assert_equal 1, preview['data_counts']['tags']
    assert_equal 1, preview['data_counts']['documents']
    assert_equal 0, preview['encrypted_documents']
  end

  test 'should reject unsupported schema_version in preview' do
    post :preview, params: { import: @unsupported_version_data }, format: :json

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not_empty json_response['errors']
    assert_includes json_response['errors'].first, 'Unsupported schema_version'
  end

  test 'should import with dry_run header (no actual changes)' do
    original_folder_count = @user.folders.count
    original_doc_count = @user.documents.count

    request.headers['X-Dry-Run'] = 'true'
    post :create, params: { import: @valid_export_data }, format: :json

    assert_response :success
    json_response = JSON.parse(response.body)

    assert json_response['success']
    assert json_response['dry_run']
    assert_includes json_response['message'], 'Dry run'

    assert_equal original_folder_count, @user.folders.count
    assert_equal original_doc_count, @user.documents.count
  end

  test 'should actually import without dry_run header' do
    original_folder_count = @user.folders.count
    original_doc_count = @user.documents.count
    original_tag_count = @user.tags.count

    assert_difference -> { @user.folders.count }, 2 do
      assert_difference -> { @user.documents.count }, 1 do
        assert_difference -> { @user.tags.count }, 1 do
          post :create, params: { import: @valid_export_data }, format: :json
        end
      end
    end

    assert_response :success
    json_response = JSON.parse(response.body)

    assert json_response['success']
    assert_not json_response['dry_run']
    assert_equal 2, json_response['imported_data']['folders']
    assert_equal 1, json_response['imported_data']['documents']
    assert_equal 1, json_response['imported_data']['tags']

    imported_folder = @user.folders.find_by(name: 'Imported Work')
    assert_not_nil imported_folder

    sub_folder = @user.folders.find_by(name: 'Imported Sub')
    assert_not_nil sub_folder
    assert_equal imported_folder.id, sub_folder.folder_id

    imported_doc = @user.documents.find_by(title: 'Imported Document')
    assert_not_nil imported_doc
    assert_equal 'searchable content here', imported_doc.document_text
    assert_equal imported_folder.id, imported_doc.folder_id
    assert_equal 1, imported_doc.tags.count
    assert_equal 'Imported Tag', imported_doc.tags.first.name
  end

  test 'encrypted document import should have empty document_text' do
    @user = users(:two)
    @token = JsonWebToken.encode(user_id: @user.id)
    request.headers['Authorization'] = "Bearer #{@token}"

    assert_difference -> { @user.documents.count }, 1 do
      post :create, params: { import: @encrypted_export_data }, format: :json
    end

    assert_response :success

    encrypted_doc = @user.documents.find_by(title: 'Encrypted Import')
    assert_not_nil encrypted_doc
    assert encrypted_doc.encrypted_flag
    assert_equal '', encrypted_doc.document_text
  end

  test 'should reject import with missing schema_version' do
    invalid_data = @valid_export_data.except(:schema_version)
    post :create, params: { import: invalid_data }, format: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_not json_response['success']
    assert_includes json_response['errors'].first, 'Missing schema_version'
  end

  test 'should reject import with unsupported schema_version' do
    post :create, params: { import: @unsupported_version_data }, format: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_not json_response['success']
    assert_includes json_response['errors'].first, 'Unsupported schema_version'
  end

  test 'should return error for missing import data' do
    post :create, params: {}, format: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_not json_response['success']
    assert_includes json_response['errors'].first, 'Missing import data'
  end

  test 'should return error for invalid JSON' do
    request.content_type = 'application/json'
    post :create, body: 'invalid json', format: :json

    assert_response :unprocessable_entity
  end

  test 'should skip existing resources and add warnings' do
    @user.folders.create!(name: 'Imported Work')

    original_folder_count = @user.folders.count
    original_tag_count = @user.tags.count

    post :create, params: { import: @valid_export_data }, format: :json

    assert_response :success
    json_response = JSON.parse(response.body)

    assert json_response['success']
    assert_not_empty json_response['warnings']
    assert_includes json_response['warnings'].first, 'already exist'

    assert_equal original_folder_count + 1, @user.folders.count
    assert_equal original_tag_count + 1, @user.tags.count
  end

  test 'should import from file upload' do
    temp_file = Tempfile.new(['import', '.json'])
    temp_file.write(@valid_export_data.to_json)
    temp_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(
      temp_file.path,
      'application/json'
    )

    assert_difference -> { @user.documents.count }, 1 do
      post :create, params: { file: uploaded_file }, format: :json
    end

    assert_response :success

    temp_file.close
    temp_file.unlink
  end

  test 'should require authentication' do
    request.headers['Authorization'] = nil
    post :create, params: { import: @valid_export_data }, format: :json

    assert_response :unauthorized
  end

  test 'import should be transactional - rollback on error' do
    invalid_data = @valid_export_data.deep_dup
    invalid_data[:data][:documents][0][:title] = nil

    original_folder_count = @user.folders.count
    original_doc_count = @user.documents.count

    post :create, params: { import: invalid_data }, format: :json

    assert_response :unprocessable_entity

    assert_equal original_folder_count, @user.folders.count
    assert_equal original_doc_count, @user.documents.count
  end

  test 'preview should show encrypted document count' do
    post :preview, params: { import: @encrypted_export_data }, format: :json

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 1, json_response['preview']['encrypted_documents']
  end
end
