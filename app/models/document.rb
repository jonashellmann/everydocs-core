class Document < ActiveRecord::Base
  belongs_to :folder
  belongs_to :user
  belongs_to :state

  validates_presence_of :title, :document_date, :document_url, :user, :state, :folder
end
