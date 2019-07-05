class UsersController < ApplicationController
  skip_before_action :authorize_request, only: :create

  # return authenticated token upon signup
  def create
    user = User.create!(user_params)
    auth_token = AuthenticateUser.new(user.email, user.password).call
    response = { message: Message.account_created, auth_token: auth_token }
    json_response(response, :created)

    rescue StandardError => e
      json_response({message: 'There is already an account with this email!'})
  end

  private

  def user_params
    params.permit(:name, :email, :password, :password_confirmation)
  end
end
