class FoldersController < ApplicationController
  before_action :set_folder, only: [:show, :update, :destroy]

  # GET /folders
  def index
    @folders = current_user.folders.where("folder_id is null")
    json_response(@folders)
  end

  # GET /folders-all
  def all
    @folders = current_user.folders
    json_response(@folders)
  end

  # POST /folders
  def create
    @parent_folder = params[:folder].blank? ? nil : Folder.find(params[:folder])
    @params = {
      "name" => params[:name],
      "folder" => @parent_folder
    }

    @folder = current_user.folders.create!(@params)
    json_response(@folder, :created)
  end

  # GET /folders/:id
  def show
    json_response(@folder)
  end

  # PUT /folders/:id
  def update
    @parent_folder = params[:folder].blank? ? nil : Folder.find(params[:folder])
    @params = {
      "name" => params[:name],
      "folder" => @parent_folder
    }

    @folder.update(@params)
    head :no_content
  end

  # DELETE /folders/:id
  def destroy
    @folder.destroy
    head :no_content
  end

  private

  def set_folder
    @folder = Folder.find(params[:id])
  end
end
