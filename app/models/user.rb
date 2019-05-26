class User < ActiveRecord::Base
  has_secure_password

  has_many :documents
  has_many :folders

  validates_presence_of :name, :email, :password_digest
end
