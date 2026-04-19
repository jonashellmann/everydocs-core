module ExceptionHandler
  extend ActiveSupport::Concern

  ERROR_CODES = {
    authentication_error: 'AUTHENTICATION_ERROR',
    missing_token: 'MISSING_TOKEN',
    invalid_token: 'INVALID_TOKEN',
    expired_token: 'EXPIRED_TOKEN',
    record_not_found: 'RECORD_NOT_FOUND',
    record_invalid: 'RECORD_INVALID'
  }.freeze

  class AuthenticationError < StandardError; end
  class MissingToken < StandardError; end
  class InvalidToken < StandardError; end
  class ExpiredToken < StandardError; end

  included do
    rescue_from ActiveRecord::RecordInvalid, with: :four_twenty_two
    rescue_from ExceptionHandler::AuthenticationError, with: :unauthorized_request
    rescue_from ExceptionHandler::MissingToken, with: :unauthorized_request
    rescue_from ExceptionHandler::InvalidToken, with: :unauthorized_request
    rescue_from ExceptionHandler::ExpiredToken, with: :unauthorized_request

    rescue_from ActiveRecord::RecordNotFound do |e|
      json_response(
        {
          code: ERROR_CODES[:record_not_found],
          message: e.message
        },
        :not_found
      )
    end
  end

  private

  def four_twenty_two(e)
    json_response(
      {
        code: ERROR_CODES[:record_invalid],
        message: e.message
      },
      :unprocessable_entity
    )
  end

  def unauthorized_request(e)
    error_code = case e
                  when ExceptionHandler::AuthenticationError
                    ERROR_CODES[:authentication_error]
                  when ExceptionHandler::MissingToken
                    ERROR_CODES[:missing_token]
                  when ExceptionHandler::ExpiredToken
                    ERROR_CODES[:expired_token]
                  when ExceptionHandler::InvalidToken
                    ERROR_CODES[:invalid_token]
                  else
                    ERROR_CODES[:authentication_error]
                  end

    json_response(
      {
        code: error_code,
        message: e.message
      },
      :unauthorized
    )
  end
end
