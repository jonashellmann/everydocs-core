class Document < ActiveRecord::Base
  belongs_to :folder, optional: true
  belongs_to :user
  belongs_to :state, optional: true
  belongs_to :person, optional: true

  has_many :documenttags
  has_many :tags, through: :documenttags

  validates_presence_of :title, :document_date, :user, :document_url

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
