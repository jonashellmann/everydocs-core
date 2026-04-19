require 'test_helper'

class AuthenticationControllerTest < ActionController::TestCase
  setup do
    @user = users(:one)
    @valid_email = 'non_encrypted@example.com'
    @valid_password = 'password123'
    @invalid_password = 'wrong_password'
  end

  # ==================== Login Tests ====================

  test "login with valid credentials should return auth token" do
    post :authenticate, params: {
      email: @valid_email,
      password: @valid_password
    }
    
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    assert_not_nil json_response['auth_token']
    assert_not_nil json_response['expires_at']
    
    token = json_response['auth_token']
    payload = JsonWebToken.decode(token)
    
    assert_equal @user.id, payload[:user_id]
  end

  test "login with invalid credentials should return 401" do
    post :authenticate, params: {
      email: @valid_email,
      password: @invalid_password
    }
    
    assert_response :unauthorized
    
    json_response = JSON.parse(@response.body)
    
    assert_equal 'AUTHENTICATION_ERROR', json_response['code']
    assert_equal 'Invalid credentials', json_response['message']
  end

  test "login with non-existent email should return 401" do
    post :authenticate, params: {
      email: 'nonexistent@example.com',
      password: @valid_password
    }
    
    assert_response :unauthorized
    
    json_response = JSON.parse(@response.body)
    
    assert_equal 'AUTHENTICATION_ERROR', json_response['code']
    assert_equal 'Invalid credentials', json_response['message']
  end

  # ==================== Token Expiration Tests ====================

  test "expired token should return 401 with EXPIRED_TOKEN code" do
    expired_token = JsonWebToken.encode({ user_id: @user.id }, 1.hour.ago)
    
    @request.headers['Authorization'] = "Bearer #{expired_token}"
    
    get :index, controller: 'documents'
    
    assert_response :unauthorized
    
    json_response = JSON.parse(@response.body)
    
    assert_equal 'EXPIRED_TOKEN', json_response['code']
    assert_includes json_response['message'], 'expired'
  end

  test "valid token should allow access to protected endpoints" do
    valid_token = JsonWebToken.encode(user_id: @user.id)
    
    @request.headers['Authorization'] = "Bearer #{valid_token}"
    
    get :index, controller: 'documents'
    
    assert_response :success
  end

  test "invalid token should return 401 with INVALID_TOKEN code" do
    @request.headers['Authorization'] = "Bearer invalid_token_12345"
    
    get :index, controller: 'documents'
    
    assert_response :unauthorized
    
    json_response = JSON.parse(@response.body)
    
    assert_equal 'INVALID_TOKEN', json_response['code']
  end

  test "missing token should return 401 with MISSING_TOKEN code" do
    get :index, controller: 'documents'
    
    assert_response :unauthorized
    
    json_response = JSON.parse(@response.body)
    
    assert_equal 'MISSING_TOKEN', json_response['code']
    assert_equal 'Missing token', json_response['message']
  end

  # ==================== Refresh Token Tests ====================

  test "refresh with valid token should return new token" do
    original_token = JsonWebToken.encode(user_id: @user.id)
    
    @request.headers['Authorization'] = "Bearer #{original_token}"
    
    post :refresh
    
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    assert_not_nil json_response['auth_token']
    assert_not_nil json_response['expires_at']
    
    new_token = json_response['auth_token']
    assert_not_equal original_token, new_token
    
    payload = JsonWebToken.decode(new_token)
    assert_equal @user.id, payload[:user_id]
  end

  test "refresh with expired token should return new token" do
    expired_token = JsonWebToken.encode({ user_id: @user.id }, 1.hour.ago)
    
    @request.headers['Authorization'] = "Bearer #{expired_token}"
    
    post :refresh
    
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    assert_not_nil json_response['auth_token']
    assert_not_nil json_response['expires_at']
    
    new_token = json_response['auth_token']
    payload = JsonWebToken.decode(new_token)
    
    assert_equal @user.id, payload[:user_id]
  end

  test "refresh with invalid token should return 401" do
    @request.headers['Authorization'] = "Bearer completely_invalid_token"
    
    post :refresh
    
    assert_response :unauthorized
    
    json_response = JSON.parse(@response.body)
    
    assert_equal 'INVALID_TOKEN', json_response['code']
  end

  test "refresh without token should return 401" do
    post :refresh
    
    assert_response :unauthorized
    
    json_response = JSON.parse(@response.body)
    
    assert_equal 'MISSING_TOKEN', json_response['code']
  end

  test "refresh with token from deleted user should return 401" do
    deleted_user = User.create!(
      name: 'Deleted User',
      email: 'deleted@example.com',
      password_digest: BCrypt::Password.create('password123')
    )
    
    token = JsonWebToken.encode(user_id: deleted_user.id)
    
    deleted_user.destroy
    
    @request.headers['Authorization'] = "Bearer #{token}"
    
    post :refresh
    
    assert_response :unauthorized
    
    json_response = JSON.parse(@response.body)
    
    assert_equal 'INVALID_TOKEN', json_response['code']
  end

  # ==================== Token Payload Tests ====================

  test "token should include exp claim" do
    token = JsonWebToken.encode(user_id: @user.id)
    
    payload = JsonWebToken.decode(token)
    
    assert_not_nil payload[:exp]
    assert payload[:exp] > Time.current.to_i
  end

  test "decode_without_expiry_validation should decode expired token" do
    expired_token = JsonWebToken.encode({ user_id: @user.id }, 1.hour.ago)
    
    assert_raises(ExceptionHandler::ExpiredToken) do
      JsonWebToken.decode(expired_token)
    end
    
    payload = JsonWebToken.decode_without_expiry_validation(expired_token)
    
    assert_equal @user.id, payload[:user_id]
  end

  # ==================== Error Code Tests ====================

  test "different error scenarios should have distinct error codes" do
    scenarios = [
      {
        action: -> { get :index, controller: 'documents' },
        expected_code: 'MISSING_TOKEN'
      },
      {
        action: -> {
          @request.headers['Authorization'] = "Bearer invalid"
          get :index, controller: 'documents'
        },
        expected_code: 'INVALID_TOKEN'
      },
      {
        action: -> {
          expired_token = JsonWebToken.encode({ user_id: @user.id }, 1.hour.ago)
          @request.headers['Authorization'] = "Bearer #{expired_token}"
          get :index, controller: 'documents'
        },
        expected_code: 'EXPIRED_TOKEN'
      },
      {
        action: -> {
          post :authenticate, params: { email: @valid_email, password: 'wrong' }
        },
        expected_code: 'AUTHENTICATION_ERROR'
      }
    ]

    scenarios.each do |scenario|
      scenario[:action].call
      
      assert_response :unauthorized
      
      json_response = JSON.parse(@response.body)
      
      assert_equal scenario[:expected_code], json_response['code']
      assert_not_nil json_response['message']
    end
  end

  # ==================== Response Format Tests ====================

  test "successful auth response format" do
    post :authenticate, params: {
      email: @valid_email,
      password: @valid_password
    }
    
    json_response = JSON.parse(@response.body)
    
    assert_includes json_response, 'auth_token'
    assert_includes json_response, 'expires_at'
    
    assert_instance_of String, json_response['auth_token']
    assert_instance_of String, json_response['expires_at']
    
    assert_not_empty json_response['auth_token']
    assert_not_empty json_response['expires_at']
  end

  test "error response format" do
    post :authenticate, params: {
      email: @valid_email,
      password: @invalid_password
    }
    
    json_response = JSON.parse(@response.body)
    
    assert_includes json_response, 'code'
    assert_includes json_response, 'message'
    
    assert_instance_of String, json_response['code']
    assert_instance_of String, json_response['message']
    
    assert_not_empty json_response['code']
    assert_not_empty json_response['message']
  end
end
