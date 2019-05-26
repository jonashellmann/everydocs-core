class State < ActiveRecord::Base
  has_many :documents

  validates_presence_of :name
end
