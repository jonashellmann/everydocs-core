class FoldersController < ApplicationController
  before_action :set_folder, only: [:show, :update, :destroy]

  # GET /folders
  def index
    @folders = current_user.folders.where("folder_id is null")
    json_response(@folders)
  end

  # POST /folders
  def create
    @folder = current_user.folders.create!(folder_params)
    json_response(@folder, :created)
  end

  # GET /folders/:id
  def show
    json_response(@folder)
  end

  # PUT /folders/:id
  def update
    @folder.update(folder_params)
    head :no_content
  end

  # DELETE /folders/:id
  def destroy
    @folder.destroy
    head :no_content
  end

  private

  def folder_params
    params.permit(:name, :folder, :user)
  end

  def set_folder
    @folder = Folder.find(params[:id])
  end
end
