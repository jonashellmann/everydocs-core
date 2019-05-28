class PeopleController < ApplicationController
  before_action :set_person, only: [:show, :update, :destroy]

  # GET /people
  def index
    @people = current_user.people
    json_response(@people)
  end

  # POST /people
  def create
    @person = current_user.people.create!(person_params)
    json_response(@person, :created)
  end

  # GET /people/:id
  def show
    json_response(@person)
  end

  # PUT /people/:id
  def update
    @person.update(person_params)
    head :no_content
  end

  # DELETE /people/:id
  def destroy
    @person.destroy
    head :no_content
  end

  private

  def person_params
    params.permit(:name, :user)
  end

  def set_person
    @person = Person.find(params[:id])
  end
end
