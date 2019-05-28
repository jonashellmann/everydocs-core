class Person < ActiveRecord::Base
  has_many :documents

  validates_presence_of :name
end
