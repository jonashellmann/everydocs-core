class Person < ActiveRecord::Base
  belongs_to :user
  
  has_many :documents, dependent: :nullify

  validates_presence_of :name
end
