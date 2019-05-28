class WelcomeController < ApplicationController
  skip_before_action :authorize_request

  def index
    json_response({ message: "Welcome to EveryDocs. Visit https://github.com/jonashellmann/everydocs-core/ to learn more about this application."})
  end
end
