class Tag < ActiveRecord::Base
  has_many :documenttags
  has_many :documents, through: :documenttags

  validates_presence_of :name, :color
end
