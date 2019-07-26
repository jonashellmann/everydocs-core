class StatesController < ApplicationController
  before_action :set_state, only: [:show, :update, :destroy]

  # GET /states
  def index
    @states = State.where("id >= ?", 0)
    json_response(@states)
  end

  # POST /states
  def create
    @state = current_user.states.create!(state_params)
    json_response(@state, :created)
  end

  # GET /states/:id
  def show
    json_response(@state)
  end

  # PUT /states/:id
  def update
    @tag.update(state_params)
    head :no_content
  end

  # DELETE /states/:id
  def destroy
    @tag.destroy
    head :no_content
  end

  private

  def state_params
    params.permit(:name)
  end

  def set_state
    @state = State.find(params[:id])
  end
end
