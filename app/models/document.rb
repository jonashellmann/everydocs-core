class Document < ActiveRecord::Base
  belongs_to :folder
  belongs_to :user
  belongs_to :state
  belongs_to :person

  has_many :documenttags
  has_many :tags, through: :documenttags

  validates_presence_of :title, :document_date, :document_url, :user, :state, :folder

  def as_json(_options = {})
    super include: {
      folder: {only: [:id, :name]},
      state: {only: [:id, :name]},
      tags: {only: [:id, :name]},
      user: {only: [:id, :name]},
      person: {only: [:id, :name]}, 
    }
  end
end
