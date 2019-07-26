class Tag < ActiveRecord::Base
  belongs_to :user
  
  has_many :documenttags, dependent: :nullify
  has_many :documents, through: :documenttags

  validates_presence_of :name
end
