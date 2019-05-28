class Documenttag < ActiveRecord::Base
  belongs_to :document
  belongs_to :tag

  validates_presence_of :document, :tag
end
