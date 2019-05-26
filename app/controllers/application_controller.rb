class ApplicationController < ActionController::Base
  # Prevent CSRF attacks
  protect_from_forgery with: :exception

  include Response
  include ExceptionHandler

  # called before every action on controllers
  before_action :authorize_request
  attr_reader :current_user

  skip_before_filter :verify_authenticity_token

  private

  # Check for valid request token and return user
  def authorize_request
    @current_user = (AuthorizeApiRequest.new(request.headers).call)[:user]
  end
end
