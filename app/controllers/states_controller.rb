class StatesController < ApplicationController
  before_action :set_state, only: [:show]

  # GET /states
  def index
    @states = State.where("id >= ?", 0)
    json_response(@states)
  end

  # GET /states/:id
  def show
    json_response(@state)
  end

  private

  def state_params
    params.permit(:name)
  end

  def set_state
    @state = State.find(params[:id])
  end
end
