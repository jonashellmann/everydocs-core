class ImportsController < ApplicationController
  before_action :authorize_request

  DRY_RUN_HEADER = 'X-Dry-Run'

  def create
    import_data = params[:import] || params[:file]

    if import_data.blank?
      render json: {
        success: false,
        errors: ['Missing import data. Please provide either: ' \
                 '1) JSON file as multipart/form-data with key "file", or ' \
                 '2) JSON object in request body with key "import"']
      }, status: :unprocessable_entity
      return
    end

    json_data = parse_import_data(import_data)

    if json_data.nil?
      render json: {
        success: false,
        errors: ['Invalid import data format']
      }, status: :unprocessable_entity
      return
    end

    dry_run = request.headers[DRY_RUN_HEADER] == 'true' ||
              params[:dry_run] == 'true' ||
              params[:dry_run] == true

    import_service = UserImportService.new(@current_user, json_data, dry_run: dry_run)

    valid = import_service.validate
    result = import_service.execute if valid

    if valid && result
      render_success_response(import_service, dry_run)
    else
      render_error_response(import_service)
    end
  rescue JSON::ParserError => e
    render json: {
      success: false,
      errors: ["Invalid JSON format: #{e.message}"]
    }, status: :unprocessable_entity
  end

  def preview
    import_data = params[:import] || params[:file]

    if import_data.blank?
      render json: {
        success: false,
        errors: ['Missing import data']
      }, status: :unprocessable_entity
      return
    end

    json_data = parse_import_data(import_data)

    if json_data.nil?
      render json: {
        success: false,
        errors: ['Invalid import data format']
      }, status: :unprocessable_entity
      return
    end

    import_service = UserImportService.new(@current_user, json_data, dry_run: true)
    import_service.validate

    data = json_data['data'] || {}

    render json: {
      success: true,
      dry_run: true,
      preview: {
        schema_version: json_data['schema_version'],
        exported_at: json_data['exported_at'],
        source_user: json_data['user'],
        data_counts: {
          folders: data['folders']&.size || 0,
          tags: data['tags']&.size || 0,
          people: data['people']&.size || 0,
          states: data['states']&.size || 0,
          documents: data['documents']&.size || 0
        },
        encrypted_documents: data['documents']&.count { |d| d['encrypted_flag'] } || 0
      },
      warnings: import_service.warnings,
      errors: import_service.errors
    }, status: :ok
  rescue JSON::ParserError => e
    render json: {
      success: false,
      errors: ["Invalid JSON format: #{e.message}"]
    }, status: :unprocessable_entity
  end

  private

  def parse_import_data(data)
    if data.is_a?(ActionDispatch::Http::UploadedFile)
      JSON.parse(data.read)
    elsif data.is_a?(String)
      JSON.parse(data)
    elsif data.is_a?(Hash)
      data
    else
      nil
    end
  end

  def render_success_response(import_service, dry_run)
    response = {
      success: true,
      dry_run: dry_run,
      imported_data: import_service.imported_data,
      warnings: import_service.warnings
    }

    if dry_run
      response[:message] = 'Dry run completed successfully. ' \
                           'No data was actually imported. ' \
                           'Send request without X-Dry-Run header to perform actual import.'
    end

    render json: response, status: :ok
  end

  def render_error_response(import_service)
    render json: {
      success: false,
      errors: import_service.errors,
      warnings: import_service.warnings
    }, status: :unprocessable_entity
  end
end
