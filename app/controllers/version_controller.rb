class VersionController < ApplicationController
  skip_before_action :authorize_request

  # GET /version
  def version
    version = '1.5.31'
    json_response(version: version)
  end
end
