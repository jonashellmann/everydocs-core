class AuthenticationController < ApplicationController
  skip_before_action :authorize_request, only: [:authenticate, :refresh]
  
  def authenticate
    auth_token = AuthenticateUser.new(auth_params[:email], auth_params[:password]).call
    json_response(
      auth_token: auth_token,
      expires_at: JsonWebToken::DEFAULT_EXPIRY.iso8601
    )
  end

  def refresh
    token = extract_token_from_header
    return render_missing_token if token.blank?

    begin
      payload = JsonWebToken.decode_without_expiry_validation(token)
      user = User.find(payload[:user_id])
      
      new_token = JsonWebToken.encode(user_id: user.id)
      
      json_response(
        auth_token: new_token,
        expires_at: JsonWebToken::DEFAULT_EXPIRY.iso8601
      )
    rescue ActiveRecord::RecordNotFound => e
      json_response(
        {
          code: ExceptionHandler::ERROR_CODES[:invalid_token],
          message: e.message
        },
        :unauthorized
      )
    rescue ExceptionHandler::InvalidToken => e
      json_response(
        {
          code: ExceptionHandler::ERROR_CODES[:invalid_token],
          message: e.message
        },
        :unauthorized
      )
    end
  end

  private

  def auth_params
    params.permit(:email, :password)
  end

  def extract_token_from_header
    if request.headers['Authorization'].present?
      request.headers['Authorization'].split(' ').last
    end
  end

  def render_missing_token
    json_response(
      {
        code: ExceptionHandler::ERROR_CODES[:missing_token],
        message: Message.missing_token
      },
      :unauthorized
    )
  end
end
