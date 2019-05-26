class Folder < ActiveRecord::Base
  belongs_to :folder
  belongs_to :user

  has_many :documents
end
