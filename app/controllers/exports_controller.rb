class ExportsController < ApplicationController
  before_action :authorize_request

  def create
    export_service = UserExportService.new(@current_user)
    export_data = export_service.export

    filename = "everydocs_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"

    send_data export_data.to_json,
      filename: filename,
      type: 'application/json',
      disposition: 'attachment'
  end
end
