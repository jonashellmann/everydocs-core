require 'test_helper'

class ExportsControllerTest < ActionController::TestCase
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    request.headers['Authorization'] = "Bearer #{@token}"
  end

  test 'should export user data as JSON' do
    post :create, format: :json

    assert_response :success
    assert_equal 'application/json', response.content_type
    assert_includes response.headers['Content-Disposition'], 'attachment'
    assert_includes response.headers['Content-Disposition'], 'everydocs_export_'

    export_data = JSON.parse(response.body)

    assert export_data.key?('schema_version')
    assert_equal 1, export_data['schema_version']
    assert export_data.key?('exported_at')
    assert export_data.key?('user')
    assert export_data.key?('data')

    assert_equal @user.name, export_data['user']['name']
    assert_equal @user.email, export_data['user']['email']

    data = export_data['data']
    assert data.key?('folders')
    assert data.key?('tags')
    assert data.key?('people')
    assert data.key?('states')
    assert data.key?('documents')
  end

  test 'should export folders correctly' do
    post :create, format: :json
    export_data = JSON.parse(response.body)
    folders = export_data['data']['folders']

    assert folders.any? { |f| f['name'] == 'Work' }
    assert folders.any? { |f| f['name'] == 'Personal' }
  end

  test 'should export non-encrypted document with document_text' do
    doc = documents(:doc_work_draft)

    post :create, format: :json
    export_data = JSON.parse(response.body)
    documents = export_data['data']['documents']

    exported_doc = documents.find { |d| d['title'] == doc.title }
    assert_not_nil exported_doc
    assert_equal false, exported_doc['encrypted_flag']
    assert_equal doc.document_text, exported_doc['document_text']
    assert_not_includes exported_doc, 'document_url'
  end

  test 'should export encrypted document without document_text' do
    @user = users(:two)
    @token = JsonWebToken.encode(user_id: @user.id)
    request.headers['Authorization'] = "Bearer #{@token}"

    doc = documents(:doc_encrypted)

    post :create, format: :json
    export_data = JSON.parse(response.body)
    documents = export_data['data']['documents']

    exported_doc = documents.find { |d| d['title'] == doc.title }
    assert_not_nil exported_doc
    assert_equal true, exported_doc['encrypted_flag']
    assert_not_includes exported_doc, 'document_text'
    assert_not_includes exported_doc, 'document_url'
  end

  test 'should export document relationships by name, not id' do
    doc = documents(:doc_work_draft)

    post :create, format: :json
    export_data = JSON.parse(response.body)
    documents = export_data['data']['documents']

    exported_doc = documents.find { |d| d['title'] == doc.title }
    assert_not_nil exported_doc

    assert_equal doc.folder.name, exported_doc['folder_name']
    assert_equal doc.state.name, exported_doc['state_name']
    assert_equal doc.tags.pluck(:name).sort, exported_doc['tag_names'].sort
  end

  test 'should require authentication' do
    request.headers['Authorization'] = nil
    post :create, format: :json

    assert_response :unauthorized
  end

  test 'export should have consistent schema' do
    post :create, format: :json
    export_data = JSON.parse(response.body)

    assert_equal 1, export_data['schema_version']
    assert Time.parse(export_data['exported_at']).is_a?(Time)
  end
end
