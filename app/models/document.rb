class Document < ActiveRecord::Base
  belongs_to :folder
  belongs_to :user
  belongs_to :state

  has_many :groups, through: :documentgroups

  validates_presence_of :title, :document_date, :document_url, :user, :state, :folder
end
