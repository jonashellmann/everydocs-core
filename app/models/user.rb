class User < ActiveRecord::Base
  has_secure_password

  has_many :documents
  has_many :folders
  has_many :tags

  validates_presence_of :name, :email, :password_digest
end
