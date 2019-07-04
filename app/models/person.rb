class Person < ActiveRecord::Base
  belongs_to :user
  
  has_many :documents

  validates_presence_of :name
end
